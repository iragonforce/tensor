# Tensor — Arch Linux configuration snapshots

This repository contains reviewed public configuration snapshots
from the Tensor workstation.

The private `iragonforce/ops` repository remains the authoritative
source for infrastructure management and deployment.

**Do not automatically deploy this repository to a live host.**

## Contents

- Arch Linux system configuration, networking and systemd units
- Hyprland, Waybar, Rofi and desktop configuration
- PipeWire, WirePlumber, Sunshine and Shairport Sync
- Shell, Ghostty, tmux and Neovim configuration
- Custom maintenance and integration scripts
- Caddy configuration and its public X.509 root CA certificate

Paths under `user/` correspond to the user's home directory.
Paths under `system/` correspond to `/etc`, except
`system/usr/local/`, which corresponds to `/usr/local/`.
Paths under `scripts/usr/local/` also correspond to `/usr/local/`.

## Snapshot integrity

Files are copied from verified live configurations.

`user/.config/nvim/lua/custom_dashboard.lua` has exactly two
intentional snapshot-only differences: line-scoped
`-- gitleaks:allow` comments for the `recent_keys` dashboard
shortcut mapping.

Those comments are not present in the working live configuration.

## Security

The repository uses a default-deny `.gitignore` and explicit
file allowlisting.

Gitleaks runs through local pre-commit and pre-push hooks.

Excluded material includes:

- Credentials, private keys and authentication state
- Sunshine pairing and other application secrets
- Ollama models and generated model data
- Application caches, logs and runtime databases
- Package-generated utilities and generated man pages
- Private agent context under homelab and Hermes directories
- Application-support files not approved for public publication

The included Caddy root certificate contains public certificate
material only. No corresponding CA private key is included.

## Scope and limitations

This is a curated public snapshot, not an exhaustive copy of
every managed deployment target.

Some files in the private `ops` inventory intentionally remain
unpublished. Live-versus-`ops` differences are preserved rather
than resolved during public snapshot publication.

For deployment or recovery, consult the private infrastructure
repository and validate the current host state first.
