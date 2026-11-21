#!/bin/sh
# Apply the existing desktop RGB-on action. See rgb-on.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Apply the existing desktop RGB-on action.
Usage: rgb-on.sh 

Source: hosts/tensor/files/.config/hypr/scripts/rgb-on.sh in ~/ops
See man rgb-on.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
exec /home/iragonforce/.local/share/tensor-control/venv/bin/python /home/iragonforce/.local/share/tensor-control/tensor-rgb.py on
