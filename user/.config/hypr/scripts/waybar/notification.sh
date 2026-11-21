#!/bin/bash
# Invoke the existing Waybar notification integration. See notification.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Invoke the existing Waybar notification integration.
Usage: notification.sh 

Source: hosts/tensor/files/.config/hypr/scripts/waybar/notification.sh in ~/ops
See man notification.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi

while true; do
    count=$(swaync-client -c 2>/dev/null || echo 0)
    dnd=$(swaync-client -D 2>/dev/null || echo false)

    if [[ "$dnd" == "true" ]]; then
        icon="󰂛"
        class="dnd"
    elif (( count > 0 )); then
        icon="󰂚"
        class="active"
    else
        icon="󰂜"
        class="none"
    fi

    printf '{"text": "%s", "tooltip": "%s notifications", "class": "%s"}\n' \
        "$icon" "$count" "$class"
    sleep 2
done
