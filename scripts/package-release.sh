#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
VERSION="${1:-0.1.0-preview.1}"
DIST_DIR="${FINISH_INBOX_DIST_DIR:-$PROJECT_ROOT/dist}"
RELEASE_NAME="FinishInbox-v$VERSION"
STAGE_DIR="$DIST_DIR/$RELEASE_NAME"
ZIP_PATH="$DIST_DIR/$RELEASE_NAME.zip"
SHA_PATH="$ZIP_PATH.sha256"
MANIFEST_PATH="$DIST_DIR/$RELEASE_NAME.manifest.json"

SOURCE_REVISION="unknown"
GIT_TOP_LEVEL="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ "$GIT_TOP_LEVEL" == "$PROJECT_ROOT" ]]; then
  SOURCE_REVISION="$(git -C "$PROJECT_ROOT" rev-parse --verify HEAD 2>/dev/null || printf 'unknown')"
fi

APP_PATH="${FINISH_INBOX_BUILD_DIR:-$PROJECT_ROOT/.build/release-app}/FinishInbox.app"
CLI_PATH="${FINISH_INBOX_BUILD_DIR:-$PROJECT_ROOT/.build/release-app}/finish-inbox"
"$SCRIPT_DIR/build-app.sh" "$VERSION"

rm -rf "$STAGE_DIR"
rm -f "$ZIP_PATH" "$SHA_PATH" "$MANIFEST_PATH"
mkdir -p "$STAGE_DIR"
ditto "$APP_PATH" "$STAGE_DIR/FinishInbox.app"
install -m 0755 "$CLI_PATH" "$STAGE_DIR/finish-inbox"
install -m 0755 "$SCRIPT_DIR/install.sh" "$STAGE_DIR/install.sh"
install -m 0755 "$SCRIPT_DIR/install.command" "$STAGE_DIR/install.command"
install -m 0755 "$SCRIPT_DIR/uninstall.sh" "$STAGE_DIR/uninstall.sh"
install -m 0644 "$PROJECT_ROOT/LICENSE" "$STAGE_DIR/LICENSE"
install -m 0644 "$PROJECT_ROOT/README.md" "$STAGE_DIR/README.md"

cat > "$STAGE_DIR/RELEASE_STATUS.txt" <<STATUS
VERSION=$VERSION
TAG=v$VERSION
SOURCE_REVISION=$SOURCE_REVISION
SIGNING=AD_HOC
NOTARIZATION=NOT_NOTARIZED
RELEASE_CHANNEL=PREVIEW

This build has an ad-hoc code signature and has not been notarized by Apple.
STATUS

EXPECTED_TOP_LEVEL="FinishInbox.app
LICENSE
README.md
RELEASE_STATUS.txt
finish-inbox
install.command
install.sh
uninstall.sh"
ACTUAL_TOP_LEVEL="$(find "$STAGE_DIR" -mindepth 1 -maxdepth 1 -exec basename {} \; | LC_ALL=C sort)"
if [[ "$ACTUAL_TOP_LEVEL" != "$EXPECTED_TOP_LEVEL" ]]; then
  echo "Release staging directory contains a file outside the allowlist." >&2
  diff -u <(printf '%s\n' "$EXPECTED_TOP_LEVEL") <(printf '%s\n' "$ACTUAL_TOP_LEVEL") || true
  exit 1
fi

codesign --verify --deep --strict "$STAGE_DIR/FinishInbox.app"
codesign --verify --strict "$STAGE_DIR/finish-inbox"
lipo "$STAGE_DIR/FinishInbox.app/Contents/MacOS/FinishInbox" -verify_arch arm64 x86_64
lipo "$STAGE_DIR/finish-inbox" -verify_arch arm64 x86_64
"$SCRIPT_DIR/privacy-scan.sh" "$STAGE_DIR"

# Normalize archive metadata so packaging does not depend on the build time.
find "$STAGE_DIR" -exec touch -h -t 202001010000 {} +

(
  cd "$DIST_DIR"
  find "$RELEASE_NAME" -type f -print | LC_ALL=C sort | zip -X -q "$RELEASE_NAME.zip" -@
)

ZIP_SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
printf '%s  %s\n' "$ZIP_SHA" "$(basename "$ZIP_PATH")" > "$SHA_PATH"

cat > "$MANIFEST_PATH" <<EOF
{
  "schemaVersion": 1,
  "name": "FinishInbox",
  "version": "$VERSION",
  "tag": "v$VERSION",
  "sourceRevision": "$SOURCE_REVISION",
  "archive": "$(basename "$ZIP_PATH")",
  "sha256": "$ZIP_SHA",
  "architectures": ["arm64", "x86_64"],
  "bundleIdentifier": "io.github.jack1231222.FinishInbox",
  "minimumMacOSVersion": "13.0",
  "signing": "AD_HOC",
  "notarization": "NOT_NOTARIZED",
  "releaseChannel": "PREVIEW",
  "files": {
EOF

first_file=1
while IFS= read -r staged_file; do
  relative_path="${staged_file#"$STAGE_DIR/"}"
  file_sha="$(shasum -a 256 "$staged_file" | awk '{print $1}')"
  if [[ $first_file -eq 0 ]]; then
    printf ',\n' >> "$MANIFEST_PATH"
  fi
  printf '    "%s": "%s"' "$relative_path" "$file_sha" >> "$MANIFEST_PATH"
  first_file=0
done < <(find "$STAGE_DIR" -type f -print | LC_ALL=C sort)

cat >> "$MANIFEST_PATH" <<'EOF'

  }
}
EOF

printf '%s\n%s\n%s\n' "$ZIP_PATH" "$SHA_PATH" "$MANIFEST_PATH"
