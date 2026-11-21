#!/usr/bin/env bash
# Report audio status for the configured Waybar module. See audio-status.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Report audio status for the configured Waybar module.
Usage: audio-status.sh  [ARGUMENT ...]

Source: hosts/tensor/files/.config/hypr/scripts/waybar/audio-status.sh in ~/ops
See man audio-status.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
# Waybar audio status for PipeWire.
# Shows the current default sink so the bar always follows the selected primary output.

set -uo pipefail
mode="${1:-value}"

friendly_name() {
    case "$1" in
        alsa_output.usb-Generic_USB_Audio-00.HiFi__SPDIF__sink)
            printf '%s' "Edifier"
            ;;
        alsa_output.usb-Generic_USB_Audio-00.HiFi__Speaker__sink)
            printf '%s' "Beyerdynamic"
            ;;
        alsa_output.usb-beyerdynamic_GmbH___Co._KG_beyerdynamic_PRO_X_004900-00.analog-stereo)
            printf '%s' "PRO X USB"
            ;;
        *)
            pactl list sinks 2>/dev/null |
                awk -v sink="$1" '
                    $1 == "Name:" { current = $2 }
                    current == sink && $1 == "Description:" {
                        sub(/^[ \t]*Description:[ \t]*/, "")
                        print
                        exit
                    }
                '
            ;;
    esac
}

sink_kind() {
    local sink="$1"
    local name="$2"
    local haystack="${sink} ${name}"

    if grep -Eiq 'headphone|headphones|headset|beyerdynamic' <<<"$haystack"; then
        printf '%s' "headphones"
    elif grep -Eiq 'speaker|speakers|edifier|spdif|line out|analog-stereo' <<<"$haystack"; then
        printf '%s' "speakers"
    else
        printf '%s' "audio"
    fi
}

sink_volume() {
    pactl get-sink-volume "$1" 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%'
}

sink_mute() {
    pactl get-sink-mute "$1" 2>/dev/null | awk '{ print $2 }'
}


# Produce valid JSON even when device names contain special characters.
render_json() {
    MODE="$mode" python3 - "$1" "$2" "$3" <<'JSONPY'
import json
import os
import sys
MODE = os.environ["MODE"]

print(json.dumps({
    "text": sys.argv[1],
    "tooltip": sys.argv[2],
    "class": ["audio-" + MODE, sys.argv[3]],
}, ensure_ascii=False))
JSONPY
}

emit_status() {
    local sink name volume mute kind icon class label

    sink="$(pactl get-default-sink 2>/dev/null || true)"

    if [[ -z "$sink" ]]; then
        if [[ "$mode" == "icon" ]]; then
            label="󰝟"
        else
            label="N/A"
        fi
        render_json "$label" "Audio unavailable" "disconnected"
        return
    fi

    name="$(friendly_name "$sink")"
    volume="$(sink_volume "$sink")"
    mute="$(sink_mute "$sink")"

    name="${name:-Audio}"
    volume="${volume:-0}"

    kind="$(sink_kind "$sink" "$name")"
    icon="󰕾"
    class="audio"

    if [[ "$mute" == "yes" ]]; then
        icon="󰝟"
        class="muted"
    elif [[ "$kind" == "headphones" ]]; then
        icon="󰋋"
        class="headphones"
    elif [[ "$kind" == "speakers" ]]; then
        icon="󰓃"
        class="speakers"
    fi

    if [[ "$mode" == "icon" ]]; then
        label="$icon"
    else
        label="${volume}%"
    fi

    render_json "$label" \
        "Default output: ${name}
Click: choose headphones or speakers" \
        "$class"
}

cleanup() {
    if [[ -n "${sub_pid:-}" ]]; then
        kill "$sub_pid" 2>/dev/null || true
        wait "$sub_pid" 2>/dev/null || true
    fi
}

trap cleanup EXIT
trap 'exit 0' TERM INT

emit_status

while true; do
    coproc AUDIO_EVENTS {
        exec env LC_ALL=C pactl subscribe 2>/dev/null
    }

    sub_pid=$AUDIO_EVENTS_PID
    events_fd=${AUDIO_EVENTS[0]}

    while IFS= read -r event <&"$events_fd"; do
        case "$event" in
            *" on sink "*|*" on server "*|*" on card "*)
                emit_status
                ;;
        esac
    done

    cleanup
    sub_pid=""
    exec {events_fd}<&- 2>/dev/null || true

    emit_status
    sleep 2
done
