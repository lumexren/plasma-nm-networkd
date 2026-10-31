# Plasma Networkd (plasma-nm Drop-in Replacement)

KDE Plasma 6 için **systemd-networkd** tabanlı, resmi `plasma-nm` paketinin sistem düzeyinde **birebir (drop-in) alternatifi** olan modern ve hafif ağ yönetimi eklentisi.

Arch Linux sistemlerinde `NetworkManager` gerektiren ağır `plasma-nm` paketini kaldırıp, yerine hiçbir konfigürasyon bozmadan `systemd-networkd` ve `iwd` kullanan bu paketi koyabilirsiniz.

---

## 📦 Arch Linux Drop-in Paket Kurulumu (`plasma-nm` Yerine)

Proje, Arch Linux paket yöneticisi `pacman` ile tam uyumludur (`provides=('plasma-nm')`, `conflicts=('plasma-nm')`, `replaces=('plasma-nm')`).

### 1. Paketi Derleyin ve Kurun:

```bash
cd ~/Projects/plasma-networkd

# Paketi oluşturup sistemdeki plasma-nm yerine kurmak için:
makepkg -si
```
*(veya hazır derlenmiş paketi yükleyin:)*
```bash
sudo pacman -U plasma-nm-networkd-6.8.2-1-any.pkg.tar.zst
```

Bu işlem:
- Sistemdeki orijinal `plasma-nm` paketini kaldırır.
- `/usr/share/plasma/plasmoids/org.kde.plasma.networkmanagement` altına bu widget'ı kurar.
- Türkçe sistem çevirilerini (`/usr/share/locale/tr/LC_MESSAGES/`) otomatik yükler.
- Şifresiz yönetim için Polkit kuralını (`/usr/share/polkit-1/rules.d/`) sisteme ekler.
- Masaüstünüzdeki tüm panel ve Sistem Tepsisi (System Tray) girişleri hiçbir ayar yapmadan doğrudan bu widget ile çalışır.

### 2. Değişikliği Uygulayın:

```bash
plasmashell --replace &
```

---

## 🔄 Orijinal `plasma-nm` Paketine Geri Dönmek İsterseniz:

İstediğiniz zaman tek komutla resmi depodaki `plasma-nm` paketini geri yükleyebilirsiniz:

```bash
sudo pacman -S plasma-nm
```

---

## 🌟 Özellikler

- **Resmi `plasma-nm` Düzeni:** KDE'nin resmi `PlasmaExtras.ExpandableListItem`, `ListSectionHeader` ve `Toolbar` bileşenleriyle birebir aynı görünüm.
- **Akıllı Donanım Tespiti:** Wi-Fi engelliyse veya kullanılamazsa Wi-Fi bölümlerini gizler, gereksiz boşluk bırakmaz.
- **systemd-networkd Entegrasyonu:** L3 DHCP ve link yönetimi (`networkctl up/down/reconfigure/renew`).
- **Kusursuz Dil Desteği:** Plasma sistem dilini (Türkçe / İngilizce) otomatik takip eden yerleşik Gettext altyapısı.
