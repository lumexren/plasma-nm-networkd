# plasma-nm-networkd

A lightweight drop-in replacement for KDE Plasma 6's `plasma-nm`, powered by **systemd-networkd** and **NetworkManager** with `iwd` / `wpa_supplicant` support.

## Features

- **Drop-in Replacement:** Replaces official `plasma-nm` without breaking existing panel widgets or dependencies (`provides=('plasma-nm')`).
- **Official Look & Feel:** Native Plasma 6 Breeze UI layout for both the system tray plasmoid and System Settings module (`kcm_networkmanagement`).
- **Dual-Backend Support:** Works out of the box with `systemd-networkd` or `NetworkManager`.
- **Live Traffic Monitor:** Real-time download and upload speeds.
- **Smart Wi-Fi Detection:** Automatically discovers `iwd` or `wpa_supplicant`, hiding wireless controls when unavailable.
- **Passwordless Actions:** Ships with polkit rules for seamless network operations.

## Installation

### Arch Linux

Build and install replacing `plasma-nm`:

```bash
git clone https://codeberg.org/lumexren/plasma-nm-networkd.git -b 6.x
cd plasma-nm-networkd
makepkg -si
```

Apply the changes to your running session:

```bash
plasmashell --replace &
```

## Reverting to Upstream

To restore the official `plasma-nm` package at any time:

```bash
sudo pacman -S plasma-nm
```

## License

GPL-3.0-or-later
