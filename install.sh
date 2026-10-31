#!/usr/bin/env bash
set -e

PLUGIN_ID="org.kde.plasma.networkmanagement"
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

cp -r "${PACKAGE_DIR}" "${TARGET_DIR}"

# Ensure it's in System Tray shownItems
if [ -f "${PLASMA_CONFIG}" ]; then
    python3 - << 'EOF'
import re, os

config_path = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
try:
    with open(config_path, "r", encoding="utf-8") as f:
        content = f.read()

    def update_tray_list(line, item, add=True):
        if not line: return line
        key, _, val = line.partition("=")
        items = [x.strip() for x in val.split(",") if x.strip()]
        if add:
            if item not in items: items.append(item)
        else:
            items = [x for x in items if x != item]
        return f"{key}={','.join(items)}"

    lines = content.splitlines()
    new_lines = []
    in_tray_general = False

    for line in lines:
        if re.match(r"^\[Containments\]\[\d+\]\[Applets\]\[\d+\]\[General\]", line):
            in_tray_general = True
            new_lines.append(line)
            continue
        elif line.startswith("["):
            in_tray_general = False

        if in_tray_general:
            if line.startswith("extraItems="):
                line = update_tray_list(line, "org.kde.plasma.networkmanagement", add=True)
            elif line.startswith("knownItems="):
                line = update_tray_list(line, "org.kde.plasma.networkmanagement", add=True)
            elif line.startswith("shownItems="):
                line = update_tray_list(line, "org.kde.plasma.networkmanagement", add=True)

        new_lines.append(line)

    with open(config_path, "w", encoding="utf-8") as f:
        f.write("\n".join(new_lines) + "\n")
    print("==> System Tray config verified!")
except Exception as e:
    print("Warning updating tray config:", e)
EOF
fi

echo "==> Installation complete!"
echo "==> Native drop-in applet '${PLUGIN_ID}' is installed."
echo "==> Supports both systemd-networkd and NetworkManager seamlessly."
echo "==> Run 'plasmashell --replace &' to apply immediately."
