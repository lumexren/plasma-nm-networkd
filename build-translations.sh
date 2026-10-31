#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="${SCRIPT_DIR}/package"
PO_DIR="${SCRIPT_DIR}/po"
APPLET_ID="org.kde.plasma.networkd"
MO_NAME="plasma_applet_${APPLET_ID}.mo"

echo "==> Compiling translations for ${APPLET_ID}..."

mkdir -p "${PACKAGE_DIR}/contents/locale/tr/LC_MESSAGES"
mkdir -p "${HOME}/.local/share/locale/tr/LC_MESSAGES"

if command -v msgfmt >/dev/null 2>&1; then
    msgfmt "${PO_DIR}/tr.po" -o "${PACKAGE_DIR}/contents/locale/tr/LC_MESSAGES/${MO_NAME}"
    cp "${PACKAGE_DIR}/contents/locale/tr/LC_MESSAGES/${MO_NAME}" "${HOME}/.local/share/locale/tr/LC_MESSAGES/${MO_NAME}"
    echo "==> Turkish translation compiled: ${MO_NAME}"
else
    echo "Warning: msgfmt not found, skipping gettext compilation."
fi
