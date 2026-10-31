#!/usr/bin/env bash
set -e

PLUGIN_ID="org.kde.plasma.networkd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="${SCRIPT_DIR}/package"
TARGET_DIR="${HOME}/.local/share/plasma/plasmoids/${PLUGIN_ID}"

echo "==> Preparing ${PLUGIN_ID}..."
chmod +x "${PACKAGE_DIR}/contents/scripts/backend.py"

mkdir -p "${HOME}/.local/share/plasma/plasmoids"

if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --remove "${PLUGIN_ID}" 2>/dev/null || true
    kpackagetool6 --type Plasma/Applet --install "${PACKAGE_DIR}"
else
    rm -rf "${TARGET_DIR}"
    cp -r "${PACKAGE_DIR}" "${TARGET_DIR}"
fi

echo "==> Installation complete!"
echo "You can test it anytime with: ./test.sh"
