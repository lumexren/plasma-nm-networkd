#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="${SCRIPT_DIR}/package"
PO_DIR="${SCRIPT_DIR}/po"

mkdir -p "${PACKAGE_DIR}/contents/locale/tr/LC_MESSAGES"

if command -v msgfmt >/dev/null 2>&1; then
    msgfmt "${PO_DIR}/tr.po" -o "${PACKAGE_DIR}/contents/locale/tr/LC_MESSAGES/plasma_applet_org.kde.plasma.networkmanagement.mo"
    
    # Also keep alias for networkd ID
    cp "${PACKAGE_DIR}/contents/locale/tr/LC_MESSAGES/plasma_applet_org.kde.plasma.networkmanagement.mo" "${PACKAGE_DIR}/contents/locale/tr/LC_MESSAGES/plasma_applet_org.kde.plasma.networkd.mo"
    
    if [[ -z "${pkgdir:-}" && -d "${HOME}/.local/share" ]]; then
        mkdir -p "${HOME}/.local/share/locale/tr/LC_MESSAGES"
        cp "${PACKAGE_DIR}/contents/locale/tr/LC_MESSAGES/plasma_applet_org.kde.plasma.networkmanagement.mo" "${HOME}/.local/share/locale/tr/LC_MESSAGES/plasma_applet_org.kde.plasma.networkmanagement.mo"
        cp "${PACKAGE_DIR}/contents/locale/tr/LC_MESSAGES/plasma_applet_org.kde.plasma.networkmanagement.mo" "${HOME}/.local/share/locale/tr/LC_MESSAGES/plasma_applet_org.kde.plasma.networkd.mo"
    fi
    
    echo "==> Turkish translations compiled successfully."
fi
