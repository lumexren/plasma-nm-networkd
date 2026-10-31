#!/usr/bin/env bash
set -e

PLUGIN_ID="org.kde.plasma.networkd"
TARGET_DIR="${HOME}/.local/share/plasma/plasmoids/${PLUGIN_ID}"
PLASMA_CONFIG="${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"

echo "==> Uninstalling ${PLUGIN_ID}..."

if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --remove "${PLUGIN_ID}" 2>/dev/null || true
fi

rm -rf "${TARGET_DIR}"
rm -f "${HOME}/.local/share/locale/*/LC_MESSAGES/plasma_applet_${PLUGIN_ID}.mo"

# Restore plasma-nm in System Tray config
if [ -f "${PLASMA_CONFIG}" ]; then
    if grep -q "plugin=org.kde.plasma.networkd" "${PLASMA_CONFIG}"; then
        echo "==> Restoring original plasma-nm in Plasma System Tray config..."
        sed -i 's/plugin=org.kde.plasma.networkd/plugin=org.kde.plasma.networkmanagement/g' "${PLASMA_CONFIG}"
    fi
fi

echo "==> Restored original system network applet. Run 'plasmashell --replace &' to reload."
