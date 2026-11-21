#!/usr/bin/env bash
# Render the configured Waybar status icon. See icon.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Render the configured Waybar status icon.
Usage: icon.sh  [ARGUMENT ...]

Source: hosts/tensor/files/.config/hypr/scripts/waybar/icon.sh in ~/ops
See man icon.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
set -euo pipefail

case "${1:-}" in
  arch)
    printf '{"text":"󰣇","class":["arch-logo"]}\n'
    ;;
  workspace-dot)
    printf '{"text":"•","class":["workspace-dot"]}\n'
    ;;
  audio)
    printf '{"text":"󰋋","class":["audio-icon"]}\n'
    ;;
  ssd)
    printf '{"text":"<span size='\''14500'\'' rise='\''-40'\''>󱂵</span>","class":["ssd-icon"]}\n'
    ;;
  memory)
    printf '{"text":"<span size='\''15600'\'' rise='\''-120'\''></span>","class":["memory-icon"]}\n'
    ;;
  cpu)
    printf '{"text":"<span size='\''14500'\'' rise='\''-40'\''>󰍛</span>","class":["cpu-icon"]}\n'
    ;;
  gpu)
    printf '{"text":"<span size='\''14500'\'' rise='\''-40'\''>󰢮</span>","class":["gpu-icon"]}\n'
    ;;
  net)
    printf '{"text":"<span size='\''14500'\'' rise='\''-60'\''>󰀂</span>","class":["net-icon"]}\n'
    ;;
  *)
    printf '{"text":"","class":["empty-icon"]}\n'
    ;;
esac
