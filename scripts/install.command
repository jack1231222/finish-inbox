#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
"$SCRIPT_DIR/install.sh"
status=$?

echo
if [[ $status -eq 0 ]]; then
  echo "FinishInbox installation completed."
else
  echo "FinishInbox installation failed (exit $status)."
fi

if [[ -t 0 ]]; then
  read -r -p "Press Return to close this window..." _
fi
exit "$status"
