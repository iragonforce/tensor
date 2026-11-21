#!/bin/sh
# Apply the existing desktop RGB-off action. See rgb-off.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Apply the existing desktop RGB-off action.
Usage: rgb-off.sh 

Source: hosts/tensor/files/.config/hypr/scripts/rgb-off.sh in ~/ops
See man rgb-off.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
exec /home/iragonforce/.local/share/tensor-control/venv/bin/python /home/iragonforce/.local/share/tensor-control/tensor-rgb.py off
