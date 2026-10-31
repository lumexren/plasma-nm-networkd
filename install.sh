#!/usr/bin/env bash
set -e

PLUGIN_ID="org.kde.plasma.networkd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="${SCRIPT_DIR}/package"
TARGET_DIR="${HOME}/.local/share/plasma/plasmoids/${PLUGIN_ID}"
PLASMA_CONFIG="${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"

echo "==> Building translations..."
"${SCRIPT_DIR}/build-translations.sh"

echo "==> Preparing ${PLUGIN_ID}..."
chmod +x "${PACKAGE_DIR}/contents/scripts/backend.py"

mkdir -p "${HOME}/.local/share/plasma/plasmoids"

# Re-install clean package
if [ -d "${TARGET_DIR}" ]; then
    rm -rf "${TARGET_DIR}"
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --remove "${PLUGIN_ID}" 2>/dev/null || true
    kpackagetool6 --type Plasma/Applet --install "${PACKAGE_DIR}"
else
    cp -r "${PACKAGE_DIR}" "${TARGET_DIR}"
fi

# Direct drop-in replacement in System Tray configuration
if [ -f "${PLASMA_CONFIG}" ]; then
    if grep -q "plugin=org.kde.plasma.networkmanagement" "${PLASMA_CONFIG}"; then
        echo "==> Replacing plasma-nm with ${PLUGIN_ID} in Plasma System Tray config..."
        cp "${PLASMA_CONFIG}" "${PLASMA_CONFIG}.networkd.bak"
        sed -i 's/plugin=org.kde.plasma.networkmanagement/plugin=org.kde.plasma.networkd/g' "${PLASMA_CONFIG}"
        echo "==> Backup saved to ${PLASMA_CONFIG}.networkd.bak"
    fi
fi

echo "==> Installation complete!"
echo "==> plasma-nm has been replaced with plasma-networkd in your system tray."
echo "==> Full i18n support active (follows Plasma system language)."
echo "==> Run 'plasmashell --replace &' to apply instantly."
