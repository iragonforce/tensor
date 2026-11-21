#!/usr/bin/env bash
# Start the configured Waybar process for the active desktop. See start-waybar.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Start the configured Waybar process for the active desktop.
Usage: start-waybar.sh 

Source: hosts/tensor/files/.config/hypr/scripts/start-waybar.sh in ~/ops
See man start-waybar.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
set -euo pipefail

# This wrapper exists because the Waybar config targets the primary monitor dynamically.
# The JSONC template uses a fake token (`__PRIMARY_OUTPUT__`) that gets replaced here
# before Waybar starts. That lets the same config follow whichever monitor is primary.

CONFIG="$HOME/.config/waybar/config.jsonc"
TMP_CONFIG="${XDG_RUNTIME_DIR:-/tmp}/waybar-config-${USER}.jsonc"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-${USER}.lock"

# Keep all launch paths serialized. Hyprland startup, systemd user units, theme reloads,
# and resume hooks can otherwise race and create multiple visible Waybar instances.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Waybar launcher already active; skipping"
  exit 0
fi

# Detect the preferred bar output from Hyprland:
# 1. Prefer the ultrawide resolution (3440x1440).
# 2. Otherwise prefer the focused monitor.
# 3. Otherwise fall back to the first monitor Hyprland reports.
primary_output="$(hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
try:
    monitors = json.load(sys.stdin)
except Exception:
    sys.exit(1)
preferred_resolution = (3440, 1440)
preferred = None
fallback = None
for monitor in monitors:
    name = monitor.get("name")
    if not name:
        continue
    if fallback is None:
        fallback = name
    if (monitor.get("width"), monitor.get("height")) == preferred_resolution:
        preferred = name
        break
    if preferred is None and (monitor.get("focused") or monitor.get("activeWorkspace", {}).get("id") == 1):
        preferred = name
print(preferred or fallback or "")
' || true)"

# Hard fallback in case Hyprland is not ready yet when the session script launches Waybar.
if [[ -z "${primary_output}" ]]; then
  primary_output="DP-5"
fi

# Render the runtime config and launch Waybar against that generated file.
sed "s/__PRIMARY_OUTPUT__/${primary_output}/g" "$CONFIG" >"$TMP_CONFIG"

# Map Waybar first so the workspace strip is above it at the same layer-shell level.
waybar -c "$TMP_CONFIG" 9>&- &
waybar_pid=$!
sleep 0.5

# Supervise the center surface independently of Waybar's side surfaces.
# Graphical environment is imported by session-start.sh.
if ! systemctl --user restart workspace-strip.service; then
  echo "WARNING: workspace strip failed to restart" >&2
fi

cleanup() {
  systemctl --user stop workspace-strip.service 2>/dev/null || true
}
trap cleanup EXIT INT TERM
wait "$waybar_pid"
