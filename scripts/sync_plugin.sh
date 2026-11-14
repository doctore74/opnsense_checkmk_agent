#!/bin/sh
# Copies the plugin from the opnsense/plugins fork into this repository.
# Usage: scripts/sync_plugin.sh [path to the fork, default ../opnsense_plugins]
set -eu
FORK=${1:-../opnsense_plugins}
SRC="${FORK}/net-mgmt/checkmk-agent"
[ -f "${SRC}/Makefile" ] || { echo "plugin not found: ${SRC}" >&2; exit 1; }
rm -rf net-mgmt/checkmk-agent
mkdir -p net-mgmt
cp -Rp "${SRC}" net-mgmt/
echo "synced from $(git -C "${FORK}" rev-parse --short HEAD) ($(git -C "${FORK}" rev-parse --abbrev-ref HEAD))"
