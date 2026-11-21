#!/usr/bin/env bash
# Run the existing host-specific Hyprland session startup integration. See session-start.sh(1) for source and integration details.
# Keep the legacy entry point on the same autostart configuration.
exec "${HOME}/.config/hypr/scripts/session-start.sh" "$@"
