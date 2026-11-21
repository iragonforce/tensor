#!/bin/bash
# Report CPU statistics for the configured Waybar module. See cpu-stats.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Report CPU statistics for the configured Waybar module.
Usage: cpu-stats.sh 
printf '{"text":"%s° %s%%","tooltip":"CPU\\nTemp: %s°C\\nUsage: %s%%","class":["cpu-value","%s"]}\n' \
Source: hosts/tensor/files/.config/hypr/scripts/waybar/cpu-stats.sh in ~/ops
See man cpu-stats.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
set -euo pipefail

# Waybar CPU module.
# This reports two values in one compact label:
# - package temperature from lm-sensors / k10temp
# - CPU usage from /proc/stat deltas

prev_idle=0
prev_total=0

# Read the CPU temperature from lm-sensors JSON output.
# The script prefers k10temp fields because this machine is using an AMD CPU.
read_temp() {
    sensors -j 2>/dev/null | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    print("0")
    raise SystemExit

for chip, values in data.items():
    if chip.startswith("k10temp"):
        for key in ("Tctl", "Tdie", "Package id 0"):
            entry = values.get(key)
            if isinstance(entry, dict):
                for field in ("temp1_input", "temp2_input", "temp3_input"):
                    temp = entry.get(field)
                    if temp is not None:
                        print(int(round(float(temp))))
                        raise SystemExit

print("0")
'
}

while true; do
    # Sample /proc/stat and compute usage from the delta between two reads.
    read -r _ user nice system idle iowait irq softirq steal _ _ < /proc/stat
    idle_all=$((idle + iowait))
    non_idle=$((user + nice + system + irq + softirq + steal))
    total=$((idle_all + non_idle))

    if (( prev_total > 0 )); then
        diff_total=$((total - prev_total))
        diff_idle=$((idle_all - prev_idle))
        if (( diff_total > 0 )); then
            usage=$(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
        else
            usage=0
        fi
    else
        usage=0
    fi

    prev_idle=$idle_all
    prev_total=$total

    temp="$(read_temp)"
    temp="${temp:-0}"

    # Temperature thresholds drive the CSS class only.
    class="normal"
    (( temp >= 85 )) && class="critical"
    (( temp >= 70 && temp < 85 )) && class="warning"

    # Temperature is printed before usage so "41° 3%" reads naturally at a glance.
    printf '{"text":"%s° %s%%","tooltip":"CPU\\nTemp: %s°C\\nUsage: %s%%","class":["cpu-value","%s"]}\n' \
        "$temp" "$usage" "$temp" "$usage" "$class"

    # Fast enough to feel live without constantly burning CPU on the status script itself.
    sleep 2
done
