#!/bin/bash
# Report network throughput for the configured Waybar module. See net-speed.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Report network throughput for the configured Waybar module.
Usage: net-speed.sh  [ARGUMENT ...]

Source: hosts/tensor/files/.config/hypr/scripts/waybar/net-speed.sh in ~/ops
See man net-speed.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
set -euo pipefail

# Waybar network throughput module.
# This script prints upload/download as a two-line label.
# The network "hardware" icon is intentionally handled by a separate Waybar module,
# because splitting it out gives much cleaner vertical alignment than embedding it here.

detect_iface() {
    ip route show default 2>/dev/null | awk '/default/ {print $5; exit}'
}

# Convert bytes/sec to a short fixed-width human-readable bit-rate string.
# Example output: " 71 Kb/s" or "1.2 Mb/s"
format_speed() {
    local bytes_per_sec=$1
    local bits_per_sec=$((bytes_per_sec * 8))
    local value unit

    if (( bits_per_sec >= 1000000000 )); then
        value=$(awk -v v="$bits_per_sec" 'BEGIN { s=v / 1000000000; if (s >= 100) printf "%.0f", s; else if (s >= 10) printf "%.0f", s; else printf "%.1f", s }')
        unit="Gb/s"
    elif (( bits_per_sec >= 1000000 )); then
        value=$(awk -v v="$bits_per_sec" 'BEGIN { s=v / 1000000; if (s >= 100) printf "%.0f", s; else if (s >= 10) printf "%.0f", s; else printf "%.1f", s }')
        unit="Mb/s"
    else
        value=$(awk -v v="$bits_per_sec" 'BEGIN { s=v / 1000; if (s >= 100) printf "%.0f", s; else if (s >= 10) printf "%.0f", s; else printf "%.1f", s }')
        unit="Kb/s"
    fi

    printf "%3s %s" "$value" "$unit"
}

prev_rx=0
prev_tx=0
prev_iface=""
prev_time_cs=0

while true; do
    iface="$(detect_iface)"

    if [[ -z "${iface:-}" ]]; then
        # Fallback when there is no default route yet.
        printf '{"text":"offline","tooltip":"No default network interface detected","class":["net-value","disconnected"]}\n'
        prev_iface=""
        prev_time_cs=0
        sleep 1
        continue
    fi

    rx_file="/sys/class/net/$iface/statistics/rx_bytes"
    tx_file="/sys/class/net/$iface/statistics/tx_bytes"

    if [[ ! -r "$rx_file" || ! -r "$tx_file" ]]; then
        printf '{"text":"offline","tooltip":"Interface %s is unavailable","class":["net-value","disconnected"]}\n' "$iface"
        prev_iface=""
        prev_time_cs=0
        sleep 1
        continue
    fi

    cur_rx=$(<"$rx_file")
    cur_tx=$(<"$tx_file")

    read -r uptime _ < /proc/uptime
    whole="${uptime%%.*}"
    fraction="${uptime#*.}00"
    now_cs=$((10#$whole * 100 + 10#${fraction:0:2}))

    if [[ "$iface" == "$prev_iface" ]] &&
       (( prev_time_cs > 0 && now_cs > prev_time_cs &&
          cur_rx >= prev_rx && cur_tx >= prev_tx )); then
        # Convert byte counters into per-second throughput.
        delta_rx=$(( (cur_rx - prev_rx) * 100 / (now_cs - prev_time_cs) ))
        delta_tx=$(( (cur_tx - prev_tx) * 100 / (now_cs - prev_time_cs) ))
        (( delta_rx < 0 )) && delta_rx=0
        (( delta_tx < 0 )) && delta_tx=0

        up_fmt=$(format_speed "$delta_tx")
        down_fmt=$(format_speed "$delta_rx")

        # The arrows live in this text block so upload/download remain readable even if
        # the separate network hardware icon gets restyled in Waybar CSS later.
        printf '{"text":"↑ %s\\n↓ %s","tooltip":"%s\\nUpload: %s\\nDownload: %s","class":["net-value","normal"]}\n' \
            "$up_fmt" "$down_fmt" "$iface" "$up_fmt" "$down_fmt"
    fi

    prev_rx=$cur_rx
    prev_tx=$cur_tx
    prev_iface=$iface
    prev_time_cs=$now_cs
    sleep 0.5
done
