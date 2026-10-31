#!/usr/bin/env bash
set -e

PLUGIN_ID="org.kde.plasma.networkd"
INSTALL_DIR="${HOME}/.local/share/plasma/plasmoids/${PLUGIN_ID}"

echo "==> Uninstalling ${PLUGIN_ID}..."

if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --remove "${PLUGIN_ID}" 2>/dev/null || true
fi

rm -rf "${INSTALL_DIR}"

echo "==> Widget uninstalled successfully."
