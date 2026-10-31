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

    property var expandedItems: ({})
    function isItemExpanded(key) {
        return Boolean(expandedItems[key]);
    }
    function setItemExpanded(key, val) {
        expandedItems[key] = val;
    }
    function hasAnyExpandedItem() {
        for (let k in expandedItems) {
            if (expandedItems[k]) return true;
        }
        return false;
    }

    ListModel {
        id: connectionsModel
    }

    function updateConnectionsModel() {
        const search = toolbar.searchText.toLowerCase().trim();
        const links = root.backendData.links || [];
        const wifiNets = (root.plasmoidItem && root.plasmoidItem.wifiNetworks) ? root.plasmoidItem.wifiNetworks : [];
        const targetList = [];

        // 1. Connected Networks (Wired or Wireless)
        for (let i = 0; i < links.length; i++) {
            const l = links[i];
            if (l.type === "bridge" || l.name === "lo") continue;

            const isConn = (l.state === "routable" || l.state === "connected") && l.ipv4 && l.ipv4.length > 0;
            if (isConn) {
                const title = (l.type === "ether" ? i18n("Wired connection") : l.name);
                if (search && !title.toLowerCase().includes(search)) continue;

                targetList.push({
                    key: "conn_" + l.name,
                    section: i18n("Connected"),
                    type: l.type === "wlan" ? "wifi" : "ethernet",
                    name: l.name,
                    title: title,
                    icon: l.type === "wlan" ? "network-wireless-connected-100" : "network-wired-activated",
                    isConnected: true,
                    ip: l.ipv4[0] || "",
                    gateway: l.gateway || "",
                    dns: (l.dns && l.dns.join(", ")) || "",
                    mac: l.mac || "",
                    mtu: l.mtu || 1500,
                    rx_speed: l.rx_speed || 0,
                    tx_speed: l.tx_speed || 0,
                    security: "",
                    signal: 100,
                    statusText: ""
                });
            }
        }

        // 2. Available Wi-Fi Networks
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

            targetList.push({
                key: "wifi_" + ssid,
                section: i18n("Available"),
                type: "wifi",
                name: ssid,
                title: ssid,
                icon: sigIcon,
                isConnected: false,
                ip: "",
                gateway: "",
                dns: "",
                mac: "",
                mtu: 1500,
                rx_speed: 0,
                tx_speed: 0,
                security: w.security || "open",
                signal: sig,
                statusText: ""
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

                targetList.push({
                    key: "wire_" + l.name,
                    section: i18n("Available"),
                    type: "ethernet",
                    name: l.name,
                    title: title,
                    icon: "network-wired",
                    isConnected: false,
                    ip: "",
                    gateway: "",
                    dns: "",
                    mac: l.mac || "",
                    mtu: l.mtu || 1500,
                    rx_speed: 0,
                    tx_speed: 0,
                    security: "",
                    signal: 0,
                    statusText: l.state === "no-carrier" ? i18n("Cable unplugged") : i18n("Disconnected")
                });
            }
        }

        const isInteracting = root.hasAnyExpandedItem();

        // Remove obsolete entries (only if no item is currently expanded to prevent delegate disruption)
        if (!isInteracting) {
            for (let m = connectionsModel.count - 1; m >= 0; m--) {
                const k = connectionsModel.get(m).key;
                let found = false;
                for (let t = 0; t < targetList.length; t++) {
                    if (targetList[t].key === k) {
                        found = true;
                        break;
                    }
                }
                if (!found) connectionsModel.remove(m);
            }
        }

        // Synchronize in-place or append new entries
        for (let t = 0; t < targetList.length; t++) {
            const target = targetList[t];
            let existingIdx = -1;
            for (let m = 0; m < connectionsModel.count; m++) {
                if (connectionsModel.get(m).key === target.key) {
                    existingIdx = m;
                    break;
                }
            }

            if (existingIdx !== -1) {
                for (let prop in target) {
                    if (connectionsModel.get(existingIdx)[prop] !== target[prop]) {
                        connectionsModel.setProperty(existingIdx, prop, target[prop]);
                    }
                }
            } else if (!isInteracting) {
                if (t < connectionsModel.count) {
                    connectionsModel.insert(t, target);
                } else {
                    connectionsModel.append(target);
                }
            }
        }
    }

    onBackendDataChanged: updateConnectionsModel()

    Connections {
        target: root.plasmoidItem || null
        function onWifiNetworksChanged() {
            root.updateConnectionsModel()
        }
    }

    Component.onCompleted: {
        updateConnectionsModel()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // 1. TOP TOOLBAR (Wi-Fi switch, search field, scan button, flush DNS, configure)
        Toolbar {
            id: toolbar
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing / 2

            wifiAvailable: Boolean(root.wifi && root.wifi.available)
            wifiEnabled: Boolean(root.wifi && root.wifi.available)

            onSearchTextChanged: root.updateConnectionsModel()

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
            onConfigureRequested: {
                if (root.plasmoidItem) {
                    root.plasmoidItem.openSettings();
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

                model: connectionsModel

                section.property: "section"
                section.delegate: PlasmaExtras.ListSectionHeader {
                    width: listView.width
                    text: section
                }

                delegate: ConnectionItem {
                    width: listView.width
                    fullRepresentation: root
                    itemKey: model.key
                    itemData: ({
                        key: model.key,
                        type: model.type,
                        name: model.name,
                        title: model.title,
                        icon: model.icon,
                        isConnected: model.isConnected,
                        ip: model.ip,
                        gateway: model.gateway,
                        dns: model.dns ? model.dns.split(", ") : [],
                        mac: model.mac,
                        mtu: model.mtu,
                        rx_speed: model.rx_speed,
                        tx_speed: model.tx_speed,
                        security: model.security,
                        signal: model.signal,
                        statusText: model.statusText
                    })

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
                    onConfigureRequested: {
                        if (root.plasmoidItem) root.plasmoidItem.openSettings();
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
