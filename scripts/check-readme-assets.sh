#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
FAILED=0

for readme in "$PROJECT_ROOT/README.md" "$PROJECT_ROOT/README.zh-CN.md"; do
  if [[ ! -f "$readme" ]]; then
    echo "Missing README: $readme" >&2
    FAILED=1
    continue
  fi

  while IFS= read -r reference; do
    case "$reference" in
      http://*|https://*|data:*|'') continue ;;
    esac
    if [[ ! -f "$PROJECT_ROOT/$reference" ]]; then
      echo "Missing README image: $reference (referenced by $(basename "$readme"))" >&2
      FAILED=1
    fi
  done < <(sed -nE 's/.*!\[[^]]*\]\(([^ )]+)( +"[^"]*")?\).*/\1/p' "$readme")
done

if [[ $FAILED -ne 0 ]]; then
  exit 1
fi
echo "README image references exist."
