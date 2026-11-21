#!/usr/bin/env bash
# Run the existing host-specific Hyprland session startup integration. See session-start.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Run the existing host-specific Hyprland session startup integration.
Usage: session-start.sh  [ARGUMENT ...]

Source: hosts/tensor/files/.config/hypr/scripts/session-start.sh in ~/ops
See man session-start.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
set -euo pipefail

# Hyprland session bootstrap.
# This script is the single place that launches long-running desktop helpers and startup apps.
# Hyprland launches this once from its active configuration.

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Some helpers still expect DISPLAY to exist. Provide :0 when an X socket is available.
if [[ -z "${DISPLAY:-}" && -S /tmp/.X11-unix/X0 ]]; then
  export DISPLAY=:0
fi

# Per-service logs land here so startup failures can be inspected without journalctl noise.
LOGDIR="$HOME/.local/state/hypr"
mkdir -p "$LOGDIR"

# Start an exact command only if that exact command line is not already running.
# Use this for simple executables that do not need shell expansion.
run_once() {
  local name="$1"
  shift
  if pgrep -u "$USER" -fx "$*" >/dev/null 2>&1; then
    return 0
  fi
  nohup "$@" >>"$LOGDIR/${name}.log" 2>&1 &
}

# Start a shell command only if a matching process is not already running.
# Use this when the command needs quoting, env vars, pipes, or shell syntax.
run_shell_once() {
  local name="$1"
  shift
  if pgrep -u "$USER" -f "$*" >/dev/null 2>&1; then
    return 0
  fi
  nohup bash -lc "$*" >>"$LOGDIR/${name}.log" 2>&1 &
}

# Export the live graphical-session variables so systemd user services and DBus-activated apps
# inherit the correct Wayland/NVIDIA environment.
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME LIBVA_DRIVER_NAME NVD_BACKEND >>"$LOGDIR/dbus-env.log" 2>&1 || true
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY XAUTHORITY HYPRLAND_INSTANCE_SIGNATURE >>"$LOGDIR/import-environment.log" 2>&1 || true

# Keep MX Master 3 settings and gestures active in this graphical session.
# Solaar is managed by solaar.service

sleep 0.2

# XWayland normalizes monitor coordinates and may otherwise treat the leftmost 4K
# output as primary. Set the ultrawide primary flag after XWayland is available.
if command -v xrandr >/dev/null 2>&1; then
  (sleep 1; DISPLAY="${DISPLAY:-:0}" xrandr --output DP-5 --primary) >>"$LOGDIR/xrandr-primary.log" 2>&1 &
fi

# Mirror the Windows Wallpaper Engine browser's choices using a native Wayland renderer.
systemctl --user restart wallpaper-engine-sync.service >>"$LOGDIR/wallpaper-engine-sync.log" 2>&1 || true

# Notification center used by the time module and desktop notifications.
systemctl --user start swaync.service >>"$LOGDIR/swaync.log" 2>&1 || true
sleep 0.2

# Authentication agent needed by polkit prompts from GUI apps.
run_shell_once polkit '/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1'
sleep 0.2

# Clipboard history watchers for text and image payloads.
run_shell_once cliphist-text 'wl-paste --type text --watch cliphist -max-items 10000 store'
run_shell_once cliphist-image 'wl-paste --type image --watch cliphist -max-items 10000 store'
sleep 0.2

# Eww widget backend.
run_once eww-daemon eww daemon
sleep 0.2

# Waybar launcher script handles output detection and bar startup.
if ! pgrep -u "$USER" -x waybar >/dev/null 2>&1; then
  nohup ~/.config/hypr/scripts/start-waybar.sh >>"$LOGDIR/waybar.log" 2>&1 &
fi
sleep 0.2

sleep 0.2

# Idle daemon enforces lock/screen-off timers.
# Hypridle starts automatically through graphical-session.target
sleep 0.2

# OpenRGB is managed by systemd.
# Keep focus tracking independent of RGB initialization.
run_shell_once focus-daemon 'python3 ~/.config/eww/scripts/focus_daemon.py'

sleep 0.5

# RGB and fan profile persistence starts through openrgb.service.
$HOME/.local/bin/xppentablet --background >/dev/null 2>&1 || true

sleep 0.5

# Ultrawide startup workspaces: 1 zsh, 2 Obsidian, 3 Zen, 4 Steam.
# Other app windows are routed to workspace 5 by the compositor rules.
run_once ghostty-main ghostty -e /usr/bin/zsh -l
run_once obsidian "$HOME/.local/bin/obsidian-gpu"
run_once zen-browser zen-browser
run_shell_once steam 'env __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DRI_PRIME=1 DISPLAY="${DISPLAY:-:0}" steam'
# Launch the Wallpaper Engine picker after Steam; native wallpapers start earlier above.
run_once wallpaper-engine-browser "$HOME/.local/bin/wallpaper-engine-browser"
run_once tailscale-gui tailscale-gui
run_once bambu-studio flatpak run com.bambulab.BambuStudio
# Only btop launches on the secondary monitor, on workspace 10.
/usr/bin/python3 /home/iragonforce/.local/share/tensor-control/desktop.py btop >>"$LOGDIR/btop-placement.log" 2>&1 &
