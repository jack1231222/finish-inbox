#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

if [[ $# -eq 0 ]]; then
  set -- "$PROJECT_ROOT/Sources" "$PROJECT_ROOT/Resources"
fi

TEMP_FILE="$(mktemp -t finish-inbox-privacy.XXXXXX)"
trap 'rm -f "$TEMP_FILE"' EXIT

for target in "$@"; do
  if [[ ! -e "$target" ]]; then
    echo "Privacy scan target does not exist: $target" >&2
    exit 1
  fi
  if [[ -f "$target" ]]; then
    if [[ ! "$target" -ef "$SCRIPT_DIR/privacy-scan.sh" ]]; then
      strings "$target" >> "$TEMP_FILE"
    fi
  else
    while IFS= read -r file; do
      if [[ "$file" -ef "$SCRIPT_DIR/privacy-scan.sh" ]]; then
        continue
      fi
      strings "$file" >> "$TEMP_FILE"
    done < <(find "$target" -type f -print | LC_ALL=C sort)
  fi
done

if LC_ALL=C grep -En \
  '(/Users/[^/[:space:]]+/|/home/[^/[:space:]]+/|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)' \
  "$TEMP_FILE"; then
  echo "Privacy scan found a private path or credential-shaped string." >&2
  exit 1
fi

echo "Privacy string scan passed."
