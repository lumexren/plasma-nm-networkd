![plasma-nm-networkd](https://img.shields.io/badge/plasma--nm--networkd-gray?style=for-the-badge&logo=kde&logoColor=white) 
![License](https://img.shields.io/badge/License-GPL--3.0-orange?style=for-the-badge) 
![Stars](https://img.shields.io/github/stars/lumexren/plasma-nm-networkd?style=for-the-badge&color=DAA520)
![Issues](https://img.shields.io/github/issues/lumexren/plasma-nm-networkd?style=for-the-badge)
![Last Commit](https://img.shields.io/github/last-commit/lumexren/plasma-nm-networkd?style=for-the-badge&color=F7A41D)
<br>

**A lightweight, drop-in replacement for KDE Plasma 6's plasma-nm powered by systemd-networkd & NetworkManager**

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Reverting to Upstream](#reverting-to-upstream)
- [Acknowledgments](#acknowledgments)

## Overview

`plasma-nm-networkd` is a seamless drop-in replacement for KDE Plasma 6 `plasma-nm`. It allows running KDE Plasma without requiring the heavy `NetworkManager` daemon on systems powered by `systemd-networkd` and `iwd` or `wpa_supplicant`, while retaining full compatibility with `NetworkManager` if present.

It provides both the native system tray applet and the native System Settings module, matching upstream KDE Plasma 6 Breeze layout, typography, and UX conventions 1:1.

## Features

- **True Drop-in Replacement** - Directly replaces `plasma-nm` without breaking existing desktop panel widgets or system package dependencies.
- **Dual Backend Engine** - Automatically detects and operates with `systemd-networkd` or `NetworkManager`.
- **Identical Breeze UI** - Uses native Plasma components and official section headers for a seamless desktop experience.
- **System Settings Integration** - Includes a native C++ KCM module accessible directly from Plasma System Settings under Networking.
- **Live Traffic Monitoring** - Real-time calculation and display of download and upload rates on both the tray applet and settings page.
- **Smart Hardware Discovery** - Automatically detects Wi-Fi adapters and hides wireless interfaces and controls when hardware is unavailable or disabled.
- **Passwordless Actions** - Preconfigured Polkit rules for non-root link state changes, DHCP lease renewal, and DNS cache flushing.

## Architecture

| Component | Path / Identifier | Description |
|:----------|:------------------|:------------|
| **Tray Applet** | `org.kde.plasma.networkmanagement` | Native Plasma 6 plasmoid providing compact and full representations |
| **System Settings KCM** | `kcm_networkmanagement.so` | C++ Qt6/KF6 KCM module using dual-pane `Kirigami.Page` & `FormLayout` |
| **Backend Engine** | `backend.py` | Asynchronous Python daemon interfacing with `networkctl`, `resolvectl`, `nmcli`, `iwctl`, `wpa_cli` |
| **Polkit Rules** | `10-plasma-networkd.rules` | Passwordless execution for network actions without sudo prompts |

## Installation

### Arch Linux (PKGBUILD)

Clone the repository and build using `makepkg`:

```bash
git clone https://github.com/lumexren/plasma-nm-networkd.git -b 6.x
cd plasma-nm-networkd
makepkg -si
```

Apply the changes to your running Plasma session:

```bash
plasmashell --replace &
```

> [!NOTE]
> KDE Plasma caches applet QML in memory. Running `plasmashell --replace &` ensures your active session immediately loads the updated applet without needing a full reboot.

## Reverting to Upstream

To restore the official KDE `plasma-nm` package at any time:

```bash
sudo pacman -S plasma-nm
```

## Acknowledgments

- **KDE Plasma Team** - For the Breeze design system and Kirigami framework.
- **systemd Team** - For `systemd-networkd` and `systemd-resolved`.
- **Community** - For feedback, testing, and contributions.

---

<div align="center">

**Built with ❤️ by lumexren**

*Star ⭐ this repo if you find it useful!*

This project is licensed under the **GNU General Public License v3.0**. See [LICENSE](./LICENSE) for details.

</div>
