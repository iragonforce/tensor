#!/bin/bash
# Report CPU temperature for the configured Waybar module. See cpu-temp.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Report CPU temperature for the configured Waybar module.
Usage: cpu-temp.sh 

Source: hosts/tensor/files/.config/hypr/scripts/waybar/cpu-temp.sh in ~/ops
See man cpu-temp.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
# CPU temperature for waybar — reads k10temp (Ryzen 9800X3D)
# /sys/class/hwmon/hwmon6/temp1_input reports millidegrees

HWMON="/sys/class/hwmon/hwmon6/temp1_input"

while true; do
    raw=$(< "$HWMON" 2>/dev/null)
    if [[ -n "$raw" ]]; then
        temp=$(( raw / 1000 ))
        class="normal"
        (( temp >= 85 )) && class="critical"
        (( temp >= 70 && temp < 85 )) && class="warning"
        printf '{"text": "<span size=\\\"7000\\\">TEMP</span>\\n%s°", "tooltip": "CPU Package: %s°C (k10temp)", "class": "%s"}\n' \
            "$temp" "$temp" "$class"
    fi
    sleep 0.5
done
