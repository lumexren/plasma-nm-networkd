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

    # Replace plugin entries
    content = content.replace("plugin=org.kde.plasma.networkmanagement", "plugin=org.kde.plasma.networkd")

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
                line = update_tray_list(line, "org.kde.plasma.networkd", add=True)
            elif line.startswith("knownItems="):
                line = update_tray_list(line, "org.kde.plasma.networkd", add=True)
            elif line.startswith("shownItems="):
                line = update_tray_list(line, "org.kde.plasma.networkd", add=True)
            elif line.startswith("hiddenItems="):
                line = update_tray_list(line, "org.kde.plasma.networkd", add=False)

        new_lines.append(line)

    with open(config_path, "w", encoding="utf-8") as f:
        f.write("\n".join(new_lines) + "\n")
    print("==> System Tray config successfully updated (added to shownItems)!")
except Exception as e:
    print("Warning updating tray config:", e)
EOF
fi

echo "==> Installation complete!"
echo "==> Plasma System Tray is configured to display '${PLUGIN_ID}' actively."
echo "==> To apply immediately, run: 'plasmashell --replace &'"
