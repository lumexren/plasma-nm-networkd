import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras

Item {
    id: root

    property PlasmoidItem plasmoidItem: null

    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 26
    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16

    implicitWidth: Layout.preferredWidth
    implicitHeight: Layout.preferredHeight

    readonly property var backendData: (plasmoidItem && plasmoidItem.backendData) ? plasmoidItem.backendData : ({})
    readonly property var wifi: backendData.wifi || ({ available: false })

    // Build real plasma-nm unified model
    readonly property var connectionsList: {
        const list = [];
        const search = toolbar.searchText.toLowerCase().trim();

        // 1. Connected Networks (Wired or Wireless)
        const links = root.backendData.links || [];
        for (let i = 0; i < links.length; i++) {
            const l = links[i];
            if (l.type === "bridge" || l.name === "lo") continue;

            const isConn = (l.state === "routable" || l.state === "connected") && l.ipv4 && l.ipv4.length > 0;
            if (isConn) {
                const title = (l.type === "ether" ? i18n("Wired connection") : l.name);
                if (search && !title.toLowerCase().includes(search)) continue;

                list.push({
                    section: i18n("Connected"),
                    type: l.type === "wlan" ? "wifi" : "ethernet",
                    name: l.name,
                    title: title,
                    icon: l.type === "wlan" ? "network-wireless-connected-100" : "network-wired-activated",
                    isConnected: true,
                    ip: l.ipv4[0],
                    gateway: l.gateway,
                    dns: l.dns,
                    mac: l.mac,
                    mtu: l.mtu
                });
            }
        }

        // 2. Available Wi-Fi Networks
        const wifiNets = (root.plasmoidItem && root.plasmoidItem.wifiNetworks) ? root.plasmoidItem.wifiNetworks : [];
        for (let j = 0; j < wifiNets.length; j++) {
            const w = wifiNets[j];
            if (w.connected) continue;

            const ssid = w.ssid || i18n("Hidden Network");
            if (search && !ssid.toLowerCase().includes(search)) continue;

            let sigIcon = "network-wireless-signal-none";
            const sig = w.signal || 50;
            if (sig >= 80) sigIcon = "network-wireless-signal-excellent";
            else if (sig >= 60) sigIcon = "network-wireless-signal-good";
            else if (sig >= 40) sigIcon = "network-wireless-signal-ok";
            else if (sig >= 20) sigIcon = "network-wireless-signal-weak";

            list.push({
                section: i18n("Available"),
                type: "wifi",
                name: ssid,
                title: ssid,
                icon: sigIcon,
                isConnected: false,
                security: w.security || "open",
                signal: sig
            });
        }

        // 3. Disconnected Wired links (unplugged or down)
        for (let k = 0; k < links.length; k++) {
            const l = links[k];
            if (l.type === "bridge" || l.name === "lo" || l.type === "wlan") continue;
            const isConn = (l.state === "routable" || l.state === "connected") && l.ipv4 && l.ipv4.length > 0;
            if (!isConn) {
                const title = (l.type === "ether" ? i18n("Wired connection") : l.name);
                if (search && !title.toLowerCase().includes(search)) continue;

                list.push({
                    section: i18n("Available"),
                    type: "ethernet",
                    name: l.name,
                    title: title,
                    icon: "network-wired",
                    isConnected: false,
                    statusText: l.state === "no-carrier" ? i18n("Cable unplugged") : i18n("Disconnected"),
                    mac: l.mac
                });
            }
        }

        return list;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // 1. TOP TOOLBAR (Wi-Fi switch, search field, scan button, flush DNS)
        Toolbar {
            id: toolbar
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing / 2

            wifiAvailable: Boolean(root.wifi && root.wifi.available)
            wifiEnabled: Boolean(root.wifi && root.wifi.available)

            onToggleWifi: enabled => {
                const iface = (root.wifi && root.wifi.primary_interface) ? root.wifi.primary_interface : "wlan0";
                if (root.plasmoidItem) {
                    root.plasmoidItem.executeLinkAction(enabled ? "connect" : "disconnect", iface);
                }
            }
            onRefreshRequested: {
                if (root.plasmoidItem) {
                    root.plasmoidItem.refreshStatus();
                    root.plasmoidItem.scanWifi();
                }
            }
            onFlushDnsRequested: {
                if (root.plasmoidItem) {
                    root.plasmoidItem.flushDns();
                }
            }
        }

        // Inline Notification Banner
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

        // 2. MAIN UNIFIED CONNECTION LIST (matches official plasma-nm)
        PlasmaComponents3.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds

                model: root.connectionsList

                section.property: "section"
                section.delegate: PlasmaExtras.ListSectionHeader {
                    width: listView.width
                    text: section
                }

                delegate: ConnectionItem {
                    width: listView.width
                    itemData: modelData

                    onConnectRequested: (type, name, password) => {
                        if (root.plasmoidItem) {
                            if (type === "wifi") {
                                root.plasmoidItem.connectWifi(name, password);
                            } else {
                                root.plasmoidItem.executeLinkAction("connect", name);
                            }
                        }
                    }
                    onDisconnectRequested: (type, name) => {
                        if (root.plasmoidItem) {
                            if (type === "wifi") {
                                root.plasmoidItem.disconnectWifi();
                            } else {
                                root.plasmoidItem.executeLinkAction("disconnect", name);
                            }
                        }
                    }
                    onActionRequested: (action, name) => {
                        if (root.plasmoidItem) root.plasmoidItem.executeLinkAction(action, name);
                    }
                }

                // Placeholder when list is empty
                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    visible: listView.count === 0
                    iconName: "network-wireless-off"
                    text: toolbar.searchText.length > 0 ? i18n("No matches") : i18n("No available connections")
                }
            }
        }
    }
}
