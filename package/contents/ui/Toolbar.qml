import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras

RowLayout {
    id: root

    property alias searchText: searchField.text
    property bool wifiAvailable: false
    property bool wifiEnabled: true

    signal toggleWifi(bool enabled)
    signal refreshRequested()
    signal flushDnsRequested()

    spacing: Kirigami.Units.smallSpacing

    // Wi-Fi On/Off Switch (matches plasma-nm)
    PlasmaComponents3.Switch {
        id: wifiSwitch
        visible: root.wifiAvailable
        checked: root.wifiEnabled
        text: i18n("Enable Wi-Fi")
        display: PlasmaComponents3.AbstractButton.IconOnly
        icon.name: checked ? "network-wireless-on" : "network-wireless-off"
        PlasmaComponents3.ToolTip { text: wifiSwitch.text }
        onToggled: root.toggleWifi(checked)
    }

    // Search Field (matches plasma-nm)
    PlasmaExtras.SearchField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: i18n("Search…")
    }

    // Scan / Refresh Button
    PlasmaComponents3.ToolButton {
        icon.name: "view-refresh"
        display: PlasmaComponents3.AbstractButton.IconOnly
        PlasmaComponents3.ToolTip { text: i18n("Scan for networks") }
        onClicked: root.refreshRequested()
    }

    // Flush DNS Resolver Cache
    PlasmaComponents3.ToolButton {
        icon.name: "edit-clear-history"
        display: PlasmaComponents3.AbstractButton.IconOnly
        PlasmaComponents3.ToolTip { text: i18n("Flush DNS Cache") }
        onClicked: root.flushDnsRequested()
    }
}
