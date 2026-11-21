#!/bin/bash
# Report SSD I/O for the configured Waybar module. See ssd-io.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Report SSD I/O for the configured Waybar module.
Usage: ssd-io.sh  [ARGUMENT ...]

Source: hosts/tensor/files/.config/hypr/scripts/waybar/ssd-io.sh in ~/ops
See man ssd-io.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
set -euo pipefail

# Waybar disk usage module.
# Purpose: show root filesystem usage as a percent next to a folder/disk icon.
# Output is JSON because Waybar custom modules expect one JSON object per refresh.

PATH_TO_CHECK="/"

while true; do
    # Pull the used %, used space, total size, free space, and mount point from `df`.
    read -r used_pct used size avail mount <<< "$(df -hP "$PATH_TO_CHECK" | awk 'NR==2 {gsub(/%/, "", $5); print $5, $3, $2, $4, $6}')"

    # Thresholds only affect CSS classes, which lets Waybar recolor the module.
    class="normal"
    (( used_pct >= 90 )) && class="critical"
    (( used_pct >= 80 && used_pct < 90 )) && class="warning"

    printf '{"text":"%s%%","tooltip":"%s mounted on %s\\nUsed: %s / %s\\nFree: %s","class":["ssd-value","%s"]}\n' \
        "$used_pct" "SSD" "$mount" "$used" "$size" "$avail" "$class"

    # Disk usage does not need sub-second refreshes.
    sleep 15
done
