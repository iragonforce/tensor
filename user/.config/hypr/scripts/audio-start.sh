#!/usr/bin/env bash
# Start the existing desktop audio-session setup. See audio-start.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Start the existing desktop audio-session setup.
Usage: audio-start.sh 

Source: hosts/tensor/files/.config/hypr/scripts/audio-start.sh in ~/ops
See man audio-start.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
# Starts the audio UX pieces used by Hyprland:
# - SwayOSD for volume popups
# - EasyEffects in service mode for the DT 700 Pro X AutoEq preset

set -euo pipefail

if ! pgrep -x swayosd-server >/dev/null 2>&1; then
    swayosd-server >/tmp/swayosd.log 2>&1 &
fi

if ! command -v easyeffects >/dev/null 2>&1; then
    exit 0
fi

if ! pgrep -x easyeffects >/dev/null 2>&1; then
    easyeffects --service-mode --hide-window >/tmp/easyeffects.log 2>&1 &
fi

# Give the service enough time to register on D-Bus before asking it to load the preset.
sleep 3
easyeffects --load-preset "Beyerdynamic DT 700 Pro X AutoEq" >/tmp/easyeffects-load.log 2>&1 || true
