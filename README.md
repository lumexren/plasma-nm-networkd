# Plasma Networkd (KDE Plasma 6 Widget)

KDE Plasma 6 için **systemd-networkd** ve **iwd / wpa_supplicant** tabanlı modern, hafif ve şık `plasma-nm` alternatifi ağ yönetim widget'ı.

NetworkManager yerine `systemd-networkd`, `systemd-resolved` ve `iwd` (Intel Wireless Daemon) kullanan Arch Linux ve diğer modern Linux dağıtımlarında KDE Plasma masaüstü ile tam entegrasyon sağlar.

---

## 🌟 Özellikler

- **Panel Entegrasyonu (Compact View)**:
  - Bağlantı türüne ve durumuna göre dinamik simge (Ethernet, Wi-Fi sinyal seviyeleri, VPN/Wireguard, Çevrimdışı).
  - Hızlı bilgi tooltip'i (bağlı arayüz adı, IPv4 adresi, ağ geçidi).
- **Arayüz Yönetimi (Interfaces)**:
  - Tüm ağ kartlarının (Ethernet, Wi-Fi, Köprü/Bridge, Wireguard) anlık durumu (routable, degraded, no-carrier, unmanaged).
  - IPv4, IPv6, Ağ Geçidi (Gateway), DNS sunucuları, MAC adresi ve MTU ayrıntıları.
  - Arayüzü Açma / Kapatma (Up/Down toggle).
  - `networkctl reconfigure` (Yeniden Yapılandırma) ve `networkctl renew` (DHCP Yenileme) butonları.
- **Kablosuz Ağ Yönetimi (Wi-Fi)**:
  - `iwd` (`iwctl`) ve `wpa_supplicant` otomatik tespiti ve desteği.
  - Çevredeki Wi-Fi ağlarını tarama (Scan).
  - Sinyal gücü yüzdesi, güvenlik tipi (WPA2/WPA3, Açık) ve kilit göstergeleri.
  - Doğrudan widget içerisinden parola girerek Wi-Fi ağına bağlanma ve bağlantıyı kesme.
- **DNS & Sistem Araçları**:
  - `systemd-resolved` durum bilgisi ve arayüz bazlı aktif DNS sunucuları.
  - Tek tıkla DNS önbelleğini temizleme (`resolvectl flush-caches`).
  - `systemd-networkd` servisini yeniden yükleme (reload) veya yeniden başlatma (restart).

---

## 📂 Proje Yapısı

```
~/Projects/plasma-networkd/
├── package/                                  # Plasmoid paket kökü
│   ├── metadata.json                         # Plasma 6 applet tanımı
│   └── contents/
│       ├── config/
│       │   └── main.xml                      # KConfig ayarları
│       ├── scripts/
│       │   └── backend.py                    # JSON API sağlayan Python backend helper
│       └── ui/
│           ├── main.qml                      # Ana PlasmaItem kökü & periyodik sorgulayıcı
│           ├── CompactRepresentation.qml     # Paneldeki kompakt görünüm & simgeler
│           ├── FullRepresentation.qml        # Açılır pencere (Popup / Flyout arayüzü)
│           ├── InterfaceDelegate.qml         # Arayüz detay kartı & eylem butonları
│           ├── WifiDelegate.qml              # Wi-Fi ağ kartı, parola alanı & bağlan butonu
│           ├── DnsView.qml                   # DNS sunucuları & önbellek temizleme
│           └── StatusBadge.qml               # Renkli durum rozetleri (routable, down vb.)
├── 10-plasma-networkd.rules                  # İsteğe bağlı Polkit kuralı
├── install.sh                                # Kurulum ve kpackagetool6 kayıt betiği
├── uninstall.sh                              # Kaldırma betiği
├── test.sh                                   # Bağımsız pencerede test etme betiği
└── README.md                                 # Dokümantasyon
```

---

## 🚀 Kurulum

Widget'ı kullanıcı ortamınıza (`~/.local/share/plasma/plasmoids/org.kde.plasma.networkd`) yüklemek için:

```bash
cd ~/Projects/plasma-networkd
./install.sh
```

### Widget'ı Bağımsız Pencerede Test Etme

Kurulumdan hemen sonra test penceresi açmak için:

```bash
./test.sh
```

### Masaüstü Paneline Ekleme

1. KDE Plasma panelinize sağ tıklayın ve **"Widget Ekle..."** (Add Widgets) seçeneğini seçin.
2. Arama kutusuna **"Networkd"** yazın.
3. **"Networkd Ağ Bağlantıları"** widget'ını panelinize veya masaüstünüze sürükleyip bırakın.

---

## 🔐 Yetkilendirme (Polkit İpuçları)

Widget üzerinden `networkctl reconfigure`, `systemctl reload systemd-networkd` veya `resolvectl flush-caches` gibi yönetimsel komutları şifre sormadan doğrudan çalıştırabilmek isterseniz, projedeki polkit kuralını sisteme kopyalayabilirsiniz:

```bash
sudo cp 10-plasma-networkd.rules /etc/polkit-1/rules.d/
```

---

## 🛠️ Manuel CLI Backend Kullanımı

Widget'ın arkasındaki Python yardımcısı bağımsız olarak da test edilebilir:

```bash
# Tüm durumu JSON olarak listele
python3 package/contents/scripts/backend.py status

# Wi-Fi ağlarını tara
python3 package/contents/scripts/backend.py wifi_scan

# Bir Wi-Fi ağına bağlan
python3 package/contents/scripts/backend.py wifi_connect "AgAdi" "Parola"

# DNS önbelleğini temizle
python3 package/contents/scripts/backend.py flush_dns
```

---

## 📄 Lisans

GPL-3.0-or-later.
