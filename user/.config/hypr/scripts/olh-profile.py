#!/usr/bin/env python3
"""Switch OpenLinkHub profile for all managed devices."""
import json
import sys
import time
import urllib.request

API_BASE = "http://127.0.0.1:27003/api"


def api_get(path):
    with urllib.request.urlopen(f"{API_BASE}{path}", timeout=3) as response:
        return json.load(response)


def api_post(path, payload):
    req = urllib.request.Request(
        f"{API_BASE}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=3) as response:
        return json.load(response)


def device_profiles(device):
    return (device.get("GetDevice") or {}).get("userProfiles") or {}


def active_profiles(device):
    return [
        name
        for name, meta in device_profiles(device).items()
        if isinstance(meta, dict) and meta.get("Active")
    ]


def live_devices():
    payload = api_get("/devices/")
    devices = payload.get("devices", {})
    return {
        serial: device
        for serial, device in devices.items()
        if serial != "cluster" and device_profiles(device)
    }


profile = sys.argv[1] if len(sys.argv) > 1 else "default"

try:
    devices = live_devices()
except Exception as exc:
    print(f"OLH error: unable to enumerate devices: {exc}", file=sys.stderr)
    sys.exit(1)

for device_id, device in devices.items():
    profiles = device_profiles(device)
    if profile not in profiles:
        print(
            f"OLH: profile {profile} not present on {device_id[:8]} ({device.get('Product')})",
            file=sys.stderr,
        )
        continue

    ok = False
    last_error = None
    for _ in range(2):
        try:
            result = api_post(
                "/userProfile/change",
                {"deviceId": device_id, "userProfileName": profile},
            )
            if result.get("status") == 1:
                time.sleep(0.2)
                refreshed = live_devices().get(device_id, {})
                if profile in active_profiles(refreshed):
                    ok = True
                    break
            last_error = result
        except Exception as exc:
            last_error = exc
        time.sleep(0.2)

    if not ok:
        print(
            f"OLH: failed to set {profile} on {device_id[:8]} - {last_error}",
            file=sys.stderr,
        )
