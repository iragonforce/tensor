#!/bin/bash
# Report GPU statistics for the configured Waybar module. See gpu-stats.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Report GPU statistics for the configured Waybar module.
Usage: gpu-stats.sh 
printf '{"text":"%s° %s%%","tooltip":"GPU\\nTemp: %s°C\\nUsage: %s%%","class":["gpu-value","%s"]}\n' \
Source: hosts/tensor/files/.config/hypr/scripts/waybar/gpu-stats.sh in ~/ops
See man gpu-stats.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
set -euo pipefail

# Waybar NVIDIA GPU module.
# Uses nvidia-smi directly, because that gives both GPU utilization and die temperature.

while true; do
    util=""
    temp=""
    IFS=',' read -r util temp < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1) || true
    util="${util//[[:space:]]/}"
    temp="${temp//[[:space:]]/}"

    if [[ -n "${util:-}" && -n "${temp:-}" ]]; then
        # CSS class thresholds are temperature-based.
        class="normal"
        (( temp >= 80 )) && class="critical"
        (( temp >= 70 && temp < 80 )) && class="warning"

        printf '{"text":"%s° %s%%","tooltip":"GPU\\nTemp: %s°C\\nUsage: %s%%","class":["gpu-value","%s"]}\n' \
            "$temp" "$util" "$temp" "$util" "$class"
    else
        # Fallback text keeps the module alive if nvidia-smi is temporarily unavailable.
        printf '{"text":"N/A","tooltip":"nvidia-smi unavailable","class":["gpu-value","disconnected"]}\n'
    fi

    sleep 3
done
