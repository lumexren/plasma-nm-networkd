#!/usr/bin/env bash
set -e

PLUGIN_ID="org.kde.plasma.networkmanagement"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/install.sh"

echo "==> Launching ${PLUGIN_ID} in test window..."
plasmawindowed "${PLUGIN_ID}"
