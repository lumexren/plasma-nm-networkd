#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_NAME="plasma-nm-networkd"

echo "==> Building Arch Linux drop-in package..."
cd "${SCRIPT_DIR}"
makepkg -f --nodeps

PKG_FILE=$(ls -t plasma-nm-networkd-*.pkg.tar* 2>/dev/null | head -n 1)

if [ -z "${PKG_FILE}" ]; then
    echo "Error: Package build failed."
    exit 1
fi

echo "==> Package ready: ${PKG_FILE}"
echo ""
echo "To install as a system-wide drop-in replacement for plasma-nm:"
echo "  sudo pacman -U ${SCRIPT_DIR}/${PKG_FILE}"
echo ""
echo "This will replace the official 'plasma-nm' package and set systemd-networkd"
echo "as the native Plasma network manager across the entire system."
