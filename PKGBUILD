# Maintainer: KDE Networkd Contributors
pkgname=plasma-nm-networkd
pkgver=6.8.2
pkgrel=1
pkgdesc="Plasma applet and System Settings module powered by systemd-networkd & NetworkManager, drop-in replacement for plasma-nm"
arch=('x86_64')
license=('GPL-3.0-or-later')
depends=(
    'libplasma'
    'kcmutils'
    'kirigami'
    'kirigami-addons'
    'python'
)
optdepends=(
    'networkmanager: For NetworkManager backend support'
    'systemd: For systemd-networkd backend support'
    'iwd: Intel wireless daemon for Wi-Fi'
    'wpa_supplicant: Alternative Wi-Fi management'
)
provides=("plasma-nm=${pkgver}")
conflicts=('plasma-nm')
replaces=('plasma-nm')

build() {
    cd "${srcdir}/.."
    ./build-translations.sh
    kcm/build-kcm.sh
}

package() {
    cd "${srcdir}/.."

    # 1. Install Plasmoid
    local plasmoid_dir="${pkgdir}/usr/share/plasma/plasmoids/org.kde.plasma.networkmanagement"
    mkdir -p "${plasmoid_dir}"
    cp -r package/* "${plasmoid_dir}/"
    chmod +x "${plasmoid_dir}/contents/scripts/backend.py"

    # 2. Install KCM plugin and desktop entry for System Settings
    install -Dm755 kcm/kcm_networkmanagement.so "${pkgdir}/usr/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_networkmanagement.so"
    install -Dm644 kcm/kcm_networkmanagement.desktop "${pkgdir}/usr/share/applications/kcm_networkmanagement.desktop"

    # 3. Install translations to system locale
    local locale_dir="${pkgdir}/usr/share/locale/tr/LC_MESSAGES"
    mkdir -p "${locale_dir}"
    if [ -f "package/contents/locale/tr/LC_MESSAGES/plasma_applet_org.kde.plasma.networkmanagement.mo" ]; then
        install -Dm644 "package/contents/locale/tr/LC_MESSAGES/plasma_applet_org.kde.plasma.networkmanagement.mo" \
            "${locale_dir}/plasma_applet_org.kde.plasma.networkmanagement.mo"
    fi

    # 4. Install polkit rule
    install -Dm644 10-plasma-networkd.rules "${pkgdir}/usr/share/polkit-1/rules.d/10-plasma-networkd.rules"
}
