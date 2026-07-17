#!/bin/bash
set -euo pipefail

PURGE=0
if [[ "${1:-}" == "--purge" ]]; then
  PURGE=1
  shift
fi
if [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--purge]" >&2
  exit 2
fi

USER_HOME="${HOME:-}"
if [[ -z "$USER_HOME" || "$USER_HOME" != /* || ! -d "$USER_HOME" ]]; then
  echo "HOME must be an existing absolute user directory." >&2
  exit 1
fi
USER_HOME="$(cd "$USER_HOME" && pwd -P)"
if [[ "$USER_HOME" == "/" ]]; then
  echo "Refusing to uninstall with HOME set to the filesystem root." >&2
  exit 1
fi

TARGET_APP="$USER_HOME/Applications/FinishInbox.app"
WRAPPER="$USER_HOME/.local/bin/finish-inbox"
DATA_DIR="$USER_HOME/Library/Application Support/FinishInbox"

while IFS= read -r pid; do
  [[ -n "$pid" ]] || continue
  command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  case "$command_line" in
    "$TARGET_APP/Contents/MacOS/FinishInbox"*) kill "$pid" >/dev/null 2>&1 || true ;;
  esac
done < <(pgrep -x FinishInbox 2>/dev/null || true)

if [[ -d "$TARGET_APP" ]]; then
  rm -rf "$TARGET_APP"
fi
if [[ -f "$WRAPPER" || -L "$WRAPPER" ]]; then
  rm -f "$WRAPPER"
fi

if [[ $PURGE -eq 1 ]]; then
  if [[ -d "$DATA_DIR" ]]; then
    rm -rf "$DATA_DIR"
  fi
  echo "Removed FinishInbox, its CLI wrapper, and local configuration/state."
else
  echo "Removed FinishInbox and its CLI wrapper."
  echo "Local configuration/state was retained at $DATA_DIR"
  echo "Run this uninstaller with --purge to remove it explicitly."
fi
