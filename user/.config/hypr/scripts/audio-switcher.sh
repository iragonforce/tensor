#!/usr/bin/env bash
# Select the configured desktop audio output. See audio-switcher.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Select the configured desktop audio output.
Usage: audio-switcher.sh 

Source: hosts/tensor/files/.config/hypr/scripts/audio-switcher.sh in ~/ops
See man audio-switcher.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
# Mouse-first audio output picker for Waybar.
# Opens a compact GTK window with two large clickable tiles:
# 1 = headphones, 2 = speakers.

set -euo pipefail

python3 - <<'PY'
import os
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, Gtk

DEVICES = {
    "headphones": {
        "number": "1",
        "icon": "󰋋",
        "title": "Headphones",
        "subtitle": "Beyerdynamic",
        "sink": "alsa_output.usb-Generic_USB_Audio-00.HiFi__Speaker__sink",
    },
    "speakers": {
        "number": "2",
        "icon": "󰓃",
        "title": "Speakers",
        "subtitle": "Edifier",
        "sink": "alsa_output.usb-Generic_USB_Audio-00.HiFi__SPDIF__sink",
    },
}


def run(*args):
    return subprocess.run(args, check=False, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)


def current_sink():
    return run("pactl", "get-default-sink").stdout.strip()


def volume_for(sink):
    output = run("pactl", "get-sink-volume", sink).stdout
    for part in output.split():
        if part.endswith("%") and part[:-1].isdigit():
            return int(part[:-1])
    return 0


def select_device(device):
    sink = device["sink"]
    run("pactl", "set-default-sink", sink)

    inputs = run("pactl", "list", "short", "sink-inputs").stdout.splitlines()
    for line in inputs:
        stream_id = line.split()[0] if line.split() else ""
        if stream_id:
            run("pactl", "move-sink-input", stream_id, sink)

    volume = volume_for(sink)
    progress = str(max(0, min(volume, 100)) / 100)
    run(
        "swayosd-client",
        "--custom-message",
        f"{device['title']} selected",
        "--custom-icon",
        "audio-headphones" if device["number"] == "1" else "audio-speakers",
        "--custom-progress",
        progress,
        "--custom-progress-text",
        f"{volume}%",
    )
    Gtk.main_quit()


css = b"""
window {
  background: rgba(18, 21, 30, 0.94);
  border-radius: 18px;
}

#frame {
  padding: 18px;
}

#title {
  color: #d4e8c0;
  font-size: 15px;
  font-weight: 700;
  margin-bottom: 12px;
}

.tile {
  min-width: 170px;
  min-height: 150px;
  padding: 14px;
  margin: 0 7px;
  border-radius: 16px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(42, 63, 27, 0.58);
}

.tile:hover {
  background: rgba(149, 180, 106, 0.24);
  border-color: rgba(181, 212, 138, 0.72);
}

.tile.active {
  background: rgba(149, 180, 106, 0.34);
  border-color: #b5d48a;
}

.number {
  color: #b5d48a;
  font-size: 18px;
  font-weight: 800;
}

.icon {
  color: #d4e8c0;
  font-size: 58px;
}

.device-title {
  color: #d4e8c0;
  font-size: 16px;
  font-weight: 800;
}

.device-subtitle {
  color: rgba(212, 232, 192, 0.68);
  font-size: 12px;
}
"""

provider = Gtk.CssProvider()
provider.load_from_data(css)
Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(),
    provider,
    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
)

window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
window.set_title("Audio Output")
window.set_decorated(False)
window.set_keep_above(True)
window.set_position(Gtk.WindowPosition.CENTER)
window.set_resizable(False)
window.connect("destroy", Gtk.main_quit)
window.connect("key-press-event", lambda _w, event: select_device(DEVICES["headphones"]) if event.keyval == Gdk.KEY_1 else select_device(DEVICES["speakers"]) if event.keyval == Gdk.KEY_2 else Gtk.main_quit() if event.keyval == Gdk.KEY_Escape else False)

frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
frame.set_name("frame")
window.add(frame)

title = Gtk.Label(label="Select audio output")
title.set_name("title")
title.set_halign(Gtk.Align.START)
frame.pack_start(title, False, False, 0)

row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
frame.pack_start(row, False, False, 0)

active_sink = current_sink()

for key in ("headphones", "speakers"):
    device = DEVICES[key]
    tile = Gtk.EventBox()
    tile.get_style_context().add_class("tile")
    if active_sink == device["sink"]:
        tile.get_style_context().add_class("active")
    tile.connect("button-press-event", lambda _tile, _event, selected=device: select_device(selected))

    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    tile.add(content)

    number = Gtk.Label(label=device["number"])
    number.get_style_context().add_class("number")
    number.set_halign(Gtk.Align.START)
    content.pack_start(number, False, False, 0)

    icon = Gtk.Label(label=device["icon"])
    icon.get_style_context().add_class("icon")
    icon.set_justify(Gtk.Justification.CENTER)
    content.pack_start(icon, True, True, 0)

    device_title = Gtk.Label(label=device["title"])
    device_title.get_style_context().add_class("device-title")
    content.pack_start(device_title, False, False, 0)

    subtitle = Gtk.Label(label=device["subtitle"])
    subtitle.get_style_context().add_class("device-subtitle")
    content.pack_start(subtitle, False, False, 0)

    row.pack_start(tile, False, False, 0)

window.show_all()
Gtk.main()
PY
