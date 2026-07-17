#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
VERSION="${1:-0.1.0-preview.1}"
BUILD_ROOT="${FINISH_INBOX_BUILD_DIR:-$PROJECT_ROOT/.build/release-app}"
APP_PATH="$BUILD_ROOT/FinishInbox.app"
CLI_PATH="$BUILD_ROOT/finish-inbox"
SOURCE_VERSION="$(sed -nE 's/^[[:space:]]*static let current = "([^"]+)".*/\1/p' "$PROJECT_ROOT/Sources/FinishInbox/Version.swift")"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version: $VERSION" >&2
  exit 2
fi
if [[ -z "$SOURCE_VERSION" || "$SOURCE_VERSION" != "$VERSION" ]]; then
  echo "Source version $SOURCE_VERSION does not match requested build version $VERSION." >&2
  exit 2
fi

for command_name in swift lipo plutil codesign xcrun; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

rm -rf "$BUILD_ROOT/arm64" "$BUILD_ROOT/x86_64" "$APP_PATH"
rm -f "$CLI_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

swift build \
  --package-path "$PROJECT_ROOT" \
  --configuration release \
  --product finish-inbox \
  --scratch-path "$BUILD_ROOT/arm64" \
  --triple arm64-apple-macosx13.0

swift build \
  --package-path "$PROJECT_ROOT" \
  --configuration release \
  --product finish-inbox \
  --scratch-path "$BUILD_ROOT/x86_64" \
  --triple x86_64-apple-macosx13.0

ARM_BINARY="$(find "$BUILD_ROOT/arm64" -type f -path '*/release/finish-inbox' -perm -111 -print -quit)"
X86_BINARY="$(find "$BUILD_ROOT/x86_64" -type f -path '*/release/finish-inbox' -perm -111 -print -quit)"
if [[ -z "$ARM_BINARY" || -z "$X86_BINARY" ]]; then
  echo "SwiftPM did not produce both FinishInbox architecture binaries." >&2
  exit 1
fi

for thin_binary in "$ARM_BINARY" "$X86_BINARY"; do
  MINIMUM_OS="$(xcrun vtool -show-build "$thin_binary" | awk '$1 == "minos" { print $2; exit }')"
  if [[ "$MINIMUM_OS" != "13.0" ]]; then
    echo "Unexpected macOS deployment target $MINIMUM_OS in $thin_binary (expected 13.0)." >&2
    exit 1
  fi
done

lipo -create "$ARM_BINARY" "$X86_BINARY" -output "$CLI_PATH"
chmod 0755 "$CLI_PATH"
lipo "$CLI_PATH" -verify_arch arm64 x86_64
codesign --force --sign - --timestamp=none --options runtime "$CLI_PATH"
codesign --verify --strict --verbose=2 "$CLI_PATH"
cp "$CLI_PATH" "$APP_PATH/Contents/MacOS/FinishInbox"
chmod 0755 "$APP_PATH/Contents/MacOS/FinishInbox"

cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_ROOT/Resources/FinishInbox.icns" "$APP_PATH/Contents/Resources/FinishInbox.icns"
PLIST_VERSION="${VERSION%%-*}"
plutil -replace CFBundleShortVersionString -string "$PLIST_VERSION" "$APP_PATH/Contents/Info.plist"
plutil -replace FinishInboxVersion -string "$VERSION" "$APP_PATH/Contents/Info.plist"
plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null

codesign --force --deep --sign - --timestamp=none --options runtime "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

printf '%s\n' "$APP_PATH"
printf '%s\n' "$CLI_PATH"
