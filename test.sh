#!/usr/bin/env bash
set -e

PLUGIN_ID="org.kde.plasma.networkd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run install first to ensure latest changes are in place
"${SCRIPT_DIR}/install.sh"

echo "==> Launching ${PLUGIN_ID} in test window..."
plasmawindowed "${PLUGIN_ID}"
