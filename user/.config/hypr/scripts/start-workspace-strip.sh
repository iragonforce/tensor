#!/usr/bin/env bash
# Start the configured workspace-strip desktop integration. See start-workspace-strip.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Start the configured workspace-strip desktop integration.
Usage: start-workspace-strip.sh  [ARGUMENT ...]

Source: hosts/tensor/files/.config/hypr/scripts/start-workspace-strip.sh in ~/ops
See man start-workspace-strip.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
set -euo pipefail
# Resolve live outputs in the strip instead of caching a transient DPMS output.
unset WAYBAR_PRIMARY_OUTPUT
# systemd/tmux can retain a socket from a previous Hyprland login.
INSTANCES="$(hyprctl instances)"
mapfile -t LIVE < <(awk '
  /^instance / {sig=$2; sub(/:$/, "", sig)}
  /^[[:space:]]*time:/ {t=$2}
  /^[[:space:]]*wl socket:/ {
    if (t >= newest) {newest=t; selected=sig; socket=$3}
  }
  END {print selected; print socket}
' <<< "$INSTANCES")
[[ -n "${LIVE[0]:-}" && -n "${LIVE[1]:-}" ]] || {
  echo "Workspace strip: no running Hyprland instance" >&2
  exit 1
}
export HYPRLAND_INSTANCE_SIGNATURE="${LIVE[0]}"
export WAYLAND_DISPLAY="${LIVE[1]}"
exec python3 "$HOME/.config/waybar/workspace-strip.py"
