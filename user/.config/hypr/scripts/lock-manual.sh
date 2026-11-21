#!/bin/bash
# Invoke the existing manual desktop lock path. See lock-manual.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Invoke the existing manual desktop lock path.
Usage: lock-manual.sh 

Source: hosts/tensor/files/.config/hypr/scripts/lock-manual.sh in ~/ops
See man lock-manual.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
set -euo pipefail
if pidof hyprlock >/dev/null 2>&1; then exit 0; fi
/home/iragonforce/.local/bin/monitors on
hyprlock
/home/iragonforce/.local/bin/monitors on
