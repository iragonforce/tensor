#!/bin/bash
# Display the configured desktop power-action menu. See power-menu.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Display the configured desktop power-action menu.
Usage: power-menu.sh 

Source: hosts/tensor/files/.config/hypr/scripts/waybar/power-menu.sh in ~/ops
See man power-menu.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
# Power menu for waybar — uses rofi

options="  Reboot\n  Power Off"

chosen=$(echo -e "$options" | rofi -dmenu -p "Power" -theme-str 'window {width: 200px;} listview {lines: 2;}')

case "$chosen" in
    *Reboot*)   systemctl reboot ;;
    *Power*)    systemctl poweroff ;;
esac
