#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SOURCE_APP="$SCRIPT_DIR/FinishInbox.app"
SOURCE_CLI="$SCRIPT_DIR/finish-inbox"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
USER_HOME="${HOME:-}"
if [[ -z "$USER_HOME" || "$USER_HOME" != /* || ! -d "$USER_HOME" ]]; then
  echo "HOME must be an existing absolute user directory." >&2
  exit 1
fi
USER_HOME="$(cd "$USER_HOME" && pwd -P)"
if [[ "$USER_HOME" == "/" ]]; then
  echo "Refusing to install with HOME set to the filesystem root." >&2
  exit 1
fi

INSTALL_ROOT="$USER_HOME/Applications"
TARGET_APP="$INSTALL_ROOT/FinishInbox.app"
BIN_DIR="$USER_HOME/.local/bin"
TARGET_CLI="$BIN_DIR/finish-inbox"
TEMP_APP="$INSTALL_ROOT/.FinishInbox.app.installing.$$"
BACKUP_APP="$INSTALL_ROOT/.FinishInbox.app.previous.$$"
TEMP_CLI="$BIN_DIR/.finish-inbox.installing.$$"
BACKUP_CLI="$BIN_DIR/.finish-inbox.previous.$$"

if [[ ! -d "$SOURCE_APP" || ! -x "$SOURCE_CLI" ]]; then
  if [[ -f "$PROJECT_ROOT/Package.swift" && -x "$SCRIPT_DIR/build-app.sh" ]]; then
    "$SCRIPT_DIR/build-app.sh" "${FINISH_INBOX_VERSION:-0.1.0-preview.1}"
    BUILD_ROOT="${FINISH_INBOX_BUILD_DIR:-$PROJECT_ROOT/.build/release-app}"
    SOURCE_APP="$BUILD_ROOT/FinishInbox.app"
    SOURCE_CLI="$BUILD_ROOT/finish-inbox"
  else
    echo "FinishInbox.app and its standalone CLI were not found next to this installer." >&2
    exit 1
  fi
fi
if [[ ! -d "$SOURCE_APP" || ! -x "$SOURCE_CLI" ]]; then
  echo "The source build did not produce both FinishInbox.app and finish-inbox." >&2
  exit 1
fi

mkdir -p "$INSTALL_ROOT" "$BIN_DIR"

cleanup() {
  rm -rf "$TEMP_APP"
  rm -f "$TEMP_CLI"
}
trap cleanup EXIT

ditto "$SOURCE_APP" "$TEMP_APP"
install -m 0755 "$SOURCE_CLI" "$TEMP_CLI"
codesign --verify --deep --strict "$TEMP_APP"
codesign --verify --strict "$TEMP_CLI"
lipo "$TEMP_CLI" -verify_arch arm64 x86_64

HAD_APP=0
HAD_CLI=0
if [[ -e "$TARGET_APP" ]]; then
  mv "$TARGET_APP" "$BACKUP_APP"
  HAD_APP=1
fi
if [[ -e "$TARGET_CLI" || -L "$TARGET_CLI" ]]; then
  if ! mv "$TARGET_CLI" "$BACKUP_CLI"; then
    if [[ $HAD_APP -eq 1 ]]; then
      mv "$BACKUP_APP" "$TARGET_APP"
    fi
    exit 1
  fi
  HAD_CLI=1
fi

if ! mv "$TEMP_APP" "$TARGET_APP" || ! mv "$TEMP_CLI" "$TARGET_CLI"; then
  rm -rf "$TARGET_APP"
  rm -f "$TARGET_CLI"
  if [[ $HAD_APP -eq 1 ]]; then
    mv "$BACKUP_APP" "$TARGET_APP"
  fi
  if [[ $HAD_CLI -eq 1 ]]; then
    mv "$BACKUP_CLI" "$TARGET_CLI"
  fi
  exit 1
fi
if [[ $HAD_APP -eq 1 ]]; then rm -rf "$BACKUP_APP"; fi
if [[ $HAD_CLI -eq 1 ]]; then rm -f "$BACKUP_CLI"; fi

if [[ "${FINISH_INBOX_NO_LAUNCH:-0}" != "1" ]]; then
  if ! open "$TARGET_APP"; then
    echo "Warning: FinishInbox was installed but could not be launched automatically." >&2
  fi
fi
echo "Installed FinishInbox.app in $INSTALL_ROOT"
echo "Installed standalone CLI at $TARGET_CLI"
echo "Existing FinishInbox configuration and state were not changed."
