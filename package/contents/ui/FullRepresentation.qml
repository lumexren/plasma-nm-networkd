import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property PlasmoidItem plasmoidItem: null

    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: Kirigami.Units.gridUnit * 28
    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.minimumHeight: Kirigami.Units.gridUnit * 18

    implicitWidth: Layout.preferredWidth
    implicitHeight: Layout.preferredHeight

    readonly property var backendData: (plasmoidItem && plasmoidItem.backendData) ? plasmoidItem.backendData : ({})
    readonly property var links: backendData.links || []
    readonly property var wifi: backendData.wifi || ({ available: false })
    readonly property var wifiNetworks: (plasmoidItem && plasmoidItem.wifiNetworks) ? plasmoidItem.wifiNetworks : []

    // Helper: Find active/connected wired links
    readonly property var connectedLinks: {
        const res = [];
        for (let i = 0; i < root.links.length; i++) {
            const l = root.links[i];
            if ((l.state === "routable" || l.state === "connected") && l.ipv4 && l.ipv4.length > 0) {
                res.push(l);
            }
        }
        return res;
    }

    // Helper: Find inactive/other links
    readonly property var otherLinks: {
        const res = [];
        for (let i = 0; i < root.links.length; i++) {
            const l = root.links[i];
            if (l.state !== "routable" && l.state !== "connected" && l.type !== "wlan") {
                res.push(l);
            }
        }
        return res;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Inline Notification Banner for errors/actions
        Kirigami.InlineMessage {
            id: bannerMsg
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: (root.plasmoidItem && root.plasmoidItem.actionMessage.length > 0) || false
            text: root.plasmoidItem ? root.plasmoidItem.actionMessage : ""
            type: (root.plasmoidItem && root.plasmoidItem.actionIsError) ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
            showCloseButton: true
            onVisibleChanged: {
                if (!visible && root.plasmoidItem) root.plasmoidItem.actionMessage = "";
            }
        }

        // Main Unified Connection List
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 0

                // SECTION 1: CONNECTED NETWORKS
                Kirigami.ListSectionHeader {
                    text: i18n("Connected")
                    visible: (root.connectedLinks.length > 0) || Boolean(root.wifi && root.wifi.connected)
                }

                Repeater {
                    model: root.connectedLinks
                    delegate: ConnectionDelegate {
                        itemType: modelData.type || "ethernet"
                        title: (modelData.type === "ether" ? i18n("Wired Connection") : modelData.name) + " (" + modelData.name + ")"
                        subtitle: (modelData.ipv4 && modelData.ipv4.length > 0) ? modelData.ipv4[0] : ""
                        iconName: modelData.type === "ether" ? "network-wired-activated" : (modelData.type === "bridge" ? "network-workgroup" : "network-vpn")
                        isConnected: true
                        details: ({
                            ifname: modelData.name,
                            ipv4: modelData.ipv4,
                            gateway: modelData.gateway,
                            dns: modelData.dns,
                            mac: modelData.mac,
                            mtu: modelData.mtu
                        })
                        onRequestAction: (action, ifname) => {
                            if (root.plasmoidItem) root.plasmoidItem.executeLinkAction(action, ifname);
                        }
                        onRequestDisconnect: () => {
                            if (root.plasmoidItem) root.plasmoidItem.executeLinkAction("down", modelData.name);
                        }
                    }
                }

                // Connected Wi-Fi (if any)
                ConnectionDelegate {
                    visible: Boolean(root.wifi && root.wifi.available && root.wifi.connected)
                    itemType: "wifi-connected"
                    title: (root.wifi && root.wifi.connected) ? root.wifi.connected.ssid : ""
                    subtitle: i18n("Connected")
                    iconName: "network-wireless-connected-100"
                    isConnected: true
                    onRequestDisconnect: () => {
                        if (root.plasmoidItem) root.plasmoidItem.disconnectWifi();
                    }
                }

                // SECTION 2: AVAILABLE WI-FI NETWORKS
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.wifi && root.wifi.available
                    spacing: 0

                    Kirigami.ListSectionHeader {
                        Layout.fillWidth: true
                        text: i18n("Available Networks")
                    }

                    QQC2.BusyIndicator {
                        running: (root.plasmoidItem && root.plasmoidItem.isScanningWifi) || false
                        visible: running
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                    }

                    QQC2.ToolButton {
                        icon.name: "view-refresh"
                        display: QQC2.AbstractButton.IconOnly
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Scan for networks")
                        enabled: (root.plasmoidItem && !root.plasmoidItem.isScanningWifi) || false
                        onClicked: if (root.plasmoidItem) root.plasmoidItem.scanWifi()
                    }
                }

                Repeater {
                    model: root.wifiNetworks
                    delegate: ConnectionDelegate {
                        visible: !modelData.connected
                        itemType: "wifi-available"
                        title: modelData.ssid || i18n("Hidden Network")
                        subtitle: (modelData.security && modelData.security !== "open") ? modelData.security.toUpperCase() : i18n("Open")
                        iconName: {
                            const sig = modelData.signal || 50;
                            if (sig >= 80) return "network-wireless-signal-excellent";
                            if (sig >= 60) return "network-wireless-signal-good";
                            if (sig >= 40) return "network-wireless-signal-ok";
                            if (sig >= 20) return "network-wireless-signal-weak";
                            return "network-wireless-signal-none";
                        }
                        isConnected: false
                        isSecured: (modelData.security && modelData.security !== "open" && modelData.security !== "none")
                        signalPct: modelData.signal || 50
                        onRequestConnect: (ssid, password) => {
                            if (root.plasmoidItem) root.plasmoidItem.connectWifi(ssid, password);
                        }
                    }
                }

                // Wi-Fi Empty state message
                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    visible: root.wifi && root.wifi.available && root.wifiNetworks.length === 0
                    text: (root.plasmoidItem && root.plasmoidItem.isScanningWifi) ? i18n("Scanning for wireless networks…") : i18n("No networks found. Click the scan button to search.")
                    horizontalAlignment: Text.AlignHCenter
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    wrapMode: Text.WordWrap
                }

                // SECTION 3: OTHER INTERFACES (Bridge / Inactive)
                Kirigami.ListSectionHeader {
                    text: i18n("Other Connections")
                    visible: root.otherLinks.length > 0
                }

                Repeater {
                    model: root.otherLinks
                    delegate: ConnectionDelegate {
                        itemType: modelData.type || "ethernet"
                        title: modelData.name
                        subtitle: modelData.state ? modelData.state.toUpperCase() : i18n("Disconnected")
                        iconName: modelData.type === "bridge" ? "network-workgroup" : (modelData.type === "wlan" ? "network-wireless" : "network-wired")
                        isConnected: false
                        details: ({
                            ifname: modelData.name,
                            ipv4: modelData.ipv4,
                            gateway: modelData.gateway,
                            dns: modelData.dns,
                            mac: modelData.mac,
                            mtu: modelData.mtu
                        })
                        onRequestAction: (action, ifname) => {
                            if (root.plasmoidItem) root.plasmoidItem.executeLinkAction(action, ifname);
                        }
                    }
                }
            }
        }

        // Bottom Compact Footer Toolbar
        Kirigami.Separator { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: "systemd-networkd"
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                color: Kirigami.Theme.disabledTextColor
            }

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: (root.backendData.systemd_networkd && root.backendData.systemd_networkd.active) ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            }

            Item { Layout.fillWidth: true }

            QQC2.ToolButton {
                icon.name: "edit-clear-history"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Flush DNS Cache")
                onClicked: if (root.plasmoidItem) root.plasmoidItem.flushDns()
            }

            QQC2.ToolButton {
                icon.name: "view-refresh"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Refresh status")
                onClicked: if (root.plasmoidItem) root.plasmoidItem.refreshStatus()
            }
        }
    }
}
