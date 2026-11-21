#!/bin/bash
# Restore the configured displays through the existing resume workflow. See monitor-resume.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Restore the configured displays through the existing resume workflow.
Usage: monitor-resume.sh 

Source: hosts/tensor/files/.config/hypr/scripts/monitor-resume.sh in ~/ops
See man monitor-resume.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
set -euo pipefail
exec /home/iragonforce/.local/bin/hibernate resume
