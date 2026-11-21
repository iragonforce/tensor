#!/bin/sh
# Run the existing host monitoring collector. See run-host.sh(1) for source and integration details.
if [ "${1-}" = '--help' ] && [ "$#" -eq 1 ]; then
  cat <<'OPS_USAGE_TEXT'
Run the existing host monitoring collector.
Usage: run-host.sh 

Source: hosts/tensor/files/usr/local/libexec/checkmk/run-host.sh in ~/ops
See man run-host.sh for the existing call sites and argument handling.
OPS_USAGE_TEXT
  exit 0
fi
/usr/local/libexec/checkmk/agent-linux
printf "<<<local:sep(0)>>>\n"
exec /usr/bin/python3 /usr/local/libexec/checkmk/local-checks.py
