import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras

PlasmaExtras.ExpandableListItem {
    id: root

    property var itemData: ({})
    property var fullRepresentation: null
    property string itemKey: ""

    signal connectRequested(string type, string name, string password)
    signal disconnectRequested(string type, string name)
    signal actionRequested(string action, string name)
    signal configureRequested()

    readonly property bool isConnected: itemData.isConnected || false
    readonly property bool isWifi: itemData.type === "wifi"
    readonly property bool isSecured: Boolean(itemData.security && itemData.security !== "open" && itemData.security !== "none")

    icon: itemData.icon || (isWifi ? "network-wireless" : "network-wired")
    title: itemData.title || ""
    subtitle: {
        if (isConnected) {
            const rx = itemData.rx_speed || 0;
            const tx = itemData.tx_speed || 0;
            const speedStr = i18nc("Download and upload rates in some unit per second", "↓ %1/s, ↑ %2/s",
                KCoreAddons.Format.formatByteSize(rx),
                KCoreAddons.Format.formatByteSize(tx));
            if (itemData.ip) {
                return itemData.ip + " • " + speedStr;
            }
            return speedStr;
        }
        if (isWifi) {
            const secStr = isSecured ? itemData.security.toUpperCase() : i18n("Open");
            return secStr + " • %" + (itemData.signal || 50);
        }
        return itemData.statusText || "";
    }

    onItemExpanded: {
        if (fullRepresentation && itemKey) {
            fullRepresentation.setItemExpanded(itemKey, true);
        }
    }

    onItemCollapsed: {
        if (fullRepresentation && itemKey) {
            fullRepresentation.setItemExpanded(itemKey, false);
        }
    }

    Component.onCompleted: {
        if (fullRepresentation && itemKey && fullRepresentation.isItemExpanded(itemKey)) {
            expand();
        }
    }

    contextualActions: [
        QQC2.Action {
            text: i18n("Configure…")
            icon.name: "configure"
            onTriggered: root.configureRequested()
        }
    ]

    // Default right action button (matches native plasma-nm)
    defaultActionButtonAction: QQC2.Action {
        icon.name: root.isConnected ? "network-disconnect-symbolic" : "network-connect-symbolic"
        text: root.isConnected ? i18n("Disconnect") : i18n("Connect")
        onTriggered: {
            if (root.isConnected) {
                root.disconnectRequested(root.itemData.type, root.itemData.name);
            } else if (root.isWifi) {
                if (root.isSecured) {
                    root.expand();
                } else {
                    root.connectRequested("wifi", root.itemData.title, "");
                }
            } else {
                // Wired ethernet connect (bring up + DHCP renew)
                root.connectRequested("ethernet", root.itemData.name, "");
            }
        }
    }

    // Expanded accordion view
    customExpandedViewContent: Component {
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            KQuickControlsAddons.Clipboard {
                id: clipboard
            }

            // If it's a Wi-Fi network not yet connected: show inline password prompt
            RowLayout {
                visible: root.isWifi && !root.isConnected
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.TextField {
                    id: pwdInput
                    Layout.fillWidth: true
                    placeholderText: i18n("Password…")
                    echoMode: showPwdBtn.checked ? TextInput.Normal : TextInput.Password
                    onAccepted: {
                        if (text.length > 0 || !root.isSecured) {
                            root.connectRequested("wifi", root.itemData.title, text);
                            root.collapse();
                        }
                    }
                }

                PlasmaComponents3.ToolButton {
                    id: showPwdBtn
                    checkable: true
                    icon.name: checked ? "visibility" : "hint"
                    PlasmaComponents3.ToolTip { text: i18n("Show password") }
                }

                PlasmaComponents3.Button {
                    text: i18n("Connect")
                    icon.name: "network-connect-symbolic"
                    enabled: pwdInput.text.length >= 8 || !root.isSecured
                    onClicked: {
                        root.connectRequested("wifi", root.itemData.title, pwdInput.text);
                        root.collapse();
                    }
                }
            }

            // If it's connected (Wired or Wi-Fi): show clean network parameters
            GridLayout {
                visible: root.isConnected
                columns: 2
                rowSpacing: 2
                columnSpacing: Kirigami.Units.largeSpacing

                PlasmaComponents3.Label {
                    text: i18n("Speed:")
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: root.isConnected
                }
                PlasmaComponents3.Label {
                    text: i18nc("Download and upload rates in some unit per second", "↓ %1/s, ↑ %2/s",
                        KCoreAddons.Format.formatByteSize(root.itemData.rx_speed || 0),
                        KCoreAddons.Format.formatByteSize(root.itemData.tx_speed || 0))
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: root.isConnected
                }

                PlasmaComponents3.Label {
                    text: i18n("IPv4:")
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: Boolean(root.itemData.ip)
                }
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: Boolean(root.itemData.ip)
                    PlasmaComponents3.Label {
                        text: root.itemData.ip || ""
                        font.family: "monospace"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "edit-copy"
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        implicitHeight: Kirigami.Units.gridUnit
                        implicitWidth: Kirigami.Units.gridUnit
                        PlasmaComponents3.ToolTip { text: i18n("Copy to clipboard") }
                        onClicked: clipboard.content = root.itemData.ip
                    }
                }

                PlasmaComponents3.Label {
                    text: i18n("Gateway:")
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: Boolean(root.itemData.gateway)
                }
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: Boolean(root.itemData.gateway)
                    PlasmaComponents3.Label {
                        text: root.itemData.gateway || ""
                        font.family: "monospace"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "edit-copy"
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        implicitHeight: Kirigami.Units.gridUnit
                        implicitWidth: Kirigami.Units.gridUnit
                        PlasmaComponents3.ToolTip { text: i18n("Copy to clipboard") }
                        onClicked: clipboard.content = root.itemData.gateway
                    }
                }

                PlasmaComponents3.Label {
                    text: i18n("DNS:")
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: Boolean(root.itemData.dns && root.itemData.dns.length > 0)
                }
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: Boolean(root.itemData.dns && root.itemData.dns.length > 0)
                    PlasmaComponents3.Label {
                        text: (root.itemData.dns && root.itemData.dns.join(", ")) || ""
                        font.family: "monospace"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "edit-copy"
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        implicitHeight: Kirigami.Units.gridUnit
                        implicitWidth: Kirigami.Units.gridUnit
                        PlasmaComponents3.ToolTip { text: i18n("Copy to clipboard") }
                        onClicked: clipboard.content = (root.itemData.dns && root.itemData.dns.join(", ")) || ""
                    }
                }

                PlasmaComponents3.Label {
                    text: i18n("Hardware address:")
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: Boolean(root.itemData.mac)
                }
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: Boolean(root.itemData.mac)
                    PlasmaComponents3.Label {
                        text: root.itemData.mac || ""
                        font.family: "monospace"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "edit-copy"
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        implicitHeight: Kirigami.Units.gridUnit
                        implicitWidth: Kirigami.Units.gridUnit
                        PlasmaComponents3.ToolTip { text: i18n("Copy to clipboard") }
                        onClicked: clipboard.content = root.itemData.mac
                    }
                }
            }

            // Quick Actions (Reconfigure, Renew)
            RowLayout {
                visible: root.isConnected && !root.isWifi
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    text: i18n("Reconfigure")
                    icon.name: "view-refresh"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    onClicked: root.actionRequested("reconfigure", root.itemData.name)
                }

                PlasmaComponents3.Button {
                    text: i18n("Renew IP")
                    icon.name: "network-connect"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    onClicked: root.actionRequested("renew", root.itemData.name)
                }
            }
        }
    }
}
