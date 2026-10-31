import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.kquickcontrolsaddons as KQuickControlsAddons

Kirigami.Page {
    id: root

    title: i18n("Wi-Fi & Networking")
    Kirigami.Theme.colorSet: Kirigami.Theme.Window

    implicitWidth: Kirigami.Units.gridUnit * 48
    implicitHeight: Kirigami.Units.gridUnit * 32

    KQuickControlsAddons.Clipboard {
        id: clipboard
    }

    readonly property var backendData: (typeof kcm !== "undefined" && kcm.backendData) ? kcm.backendData : ({})
    readonly property var links: backendData.links || []
    readonly property var wifi: backendData.wifi || ({ available: false })
    readonly property var wifiNets: (typeof kcm !== "undefined" && kcm.wifiNetworks) ? kcm.wifiNetworks : []

    // Top notification message
    header: Kirigami.InlineMessage {
        id: importFeedback
        position: Kirigami.InlineMessage.Header
        visible: (typeof kcm !== "undefined" && kcm.bannerMessage && kcm.bannerMessage.length > 0) || false
        text: (typeof kcm !== "undefined" && kcm.bannerMessage) ? kcm.bannerMessage : ""
        type: (typeof kcm !== "undefined" && kcm.bannerIsError) ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
        showCloseButton: true
    }

    ListModel {
        id: connectionsModel
    }

    function updateConnectionsModel() {
        const search = searchField.text.toLowerCase().trim();
        const targetList = [];

        // 1. Connected Networks
        for (let i = 0; i < root.links.length; i++) {
            const l = root.links[i];
            if (l.type === "bridge" || l.name === "lo") continue;
            const isConn = (l.state === "routable" || l.state === "connected") && l.ipv4 && l.ipv4.length > 0;
            if (isConn) {
                const title = (l.type === "ether" ? i18n("Wired connection") : l.name);
                if (search && !title.toLowerCase().includes(search)) continue;

                const rx = l.rx_speed || 0;
                const tx = l.tx_speed || 0;
                const speedStr = i18nc("Download and upload rates in some unit per second", "↓ %1/s, ↑ %2/s",
                    KCoreAddons.Format.formatByteSize(rx),
                    KCoreAddons.Format.formatByteSize(tx));

                targetList.push({
                    key: "conn_" + l.name,
                    section: i18n("Connected"),
                    type: l.type === "wlan" ? "wifi" : "ethernet",
                    name: l.name,
                    title: title,
                    subtitle: (l.ipv4 && l.ipv4[0] ? l.ipv4[0] + " • " : "") + speedStr,
                    icon: l.type === "wlan" ? "network-wireless-connected-100" : "network-wired-activated",
                    isConnected: true,
                    ip: (l.ipv4 && l.ipv4[0]) || "",
                    ipv4_all: (l.ipv4 && l.ipv4.join(", ")) || "",
                    gateway: l.gateway || "",
                    dns: (l.dns && l.dns.join(", ")) || "",
                    mac: l.mac || "",
                    mtu: l.mtu || 1500,
                    rx_speed: rx,
                    tx_speed: tx,
                    speed_text: speedStr,
                    security: "",
                    signal: 100,
                    statusText: l.state || i18n("Connected")
                });
            }
        }

        // 2. Available Wi-Fi Networks
        for (let j = 0; j < root.wifiNets.length; j++) {
            const w = root.wifiNets[j];
            if (w.connected) continue;
            const ssid = w.ssid || i18n("Hidden Network");
            if (search && !ssid.toLowerCase().includes(search)) continue;

            let sigIcon = "network-wireless-signal-none";
            const sig = w.signal || 50;
            if (sig >= 80) sigIcon = "network-wireless-signal-excellent";
            else if (sig >= 60) sigIcon = "network-wireless-signal-good";
            else if (sig >= 40) sigIcon = "network-wireless-signal-ok";
            else if (sig >= 20) sigIcon = "network-wireless-signal-weak";

            const secStr = (w.security && w.security !== "open" && w.security !== "none") ? w.security.toUpperCase() : i18n("Open");

            targetList.push({
                key: "wifi_" + ssid,
                section: i18n("Available"),
                type: "wifi",
                name: ssid,
                title: ssid,
                subtitle: secStr + " • %" + sig,
                icon: sigIcon,
                isConnected: false,
                ip: "",
                ipv4_all: "",
                gateway: "",
                dns: "",
                mac: "",
                mtu: 1500,
                rx_speed: 0,
                tx_speed: 0,
                speed_text: "",
                security: w.security || "open",
                signal: sig,
                statusText: i18n("Available")
            });
        }

        // 3. Disconnected / Other Interfaces
        for (let k = 0; k < root.links.length; k++) {
            const l = root.links[k];
            if (l.type === "bridge" || l.name === "lo" || l.type === "wlan") continue;
            const isConn = (l.state === "routable" || l.state === "connected") && l.ipv4 && l.ipv4.length > 0;
            if (!isConn) {
                const title = (l.type === "ether" ? i18n("Wired connection") : l.name);
                if (search && !title.toLowerCase().includes(search)) continue;

                targetList.push({
                    key: "wire_" + l.name,
                    section: i18n("Other Connections"),
                    type: "ethernet",
                    name: l.name,
                    title: title,
                    subtitle: l.state === "no-carrier" ? i18n("Cable unplugged") : i18n("Disconnected"),
                    icon: "network-wired",
                    isConnected: false,
                    ip: "",
                    ipv4_all: "",
                    gateway: "",
                    dns: "",
                    mac: l.mac || "",
                    mtu: l.mtu || 1500,
                    rx_speed: 0,
                    tx_speed: 0,
                    speed_text: "",
                    security: "",
                    signal: 0,
                    statusText: l.state === "no-carrier" ? i18n("Cable unplugged") : i18n("Disconnected")
                });
            }
        }

        // Remove obsolete items
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

        // Synchronize in-place or append new
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
            } else {
                if (t < connectionsModel.count) {
                    connectionsModel.insert(t, target);
                } else {
                    connectionsModel.append(target);
                }
            }
        }

        // Ensure a valid selection if none
        if (connectionView.currentIndex === -1 && connectionsModel.count > 0) {
            connectionView.currentIndex = 0;
        }
    }

    onBackendDataChanged: updateConnectionsModel()
    onWifiNetsChanged: updateConnectionsModel()

    Component.onCompleted: updateConnectionsModel()

    // Dual-Pane Layout matching official plasma-nm
    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // ==========================================
        // LEFT PANE: Connection List & Action Bar
        // ==========================================
        Item {
            id: leftPanel
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 15
            Layout.minimumWidth: Kirigami.Units.gridUnit * 13

            Kirigami.SearchField {
                id: searchField
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                placeholderText: i18n("Search…")
                onTextChanged: root.updateConnectionsModel()
            }

            QQC2.ScrollView {
                id: scrollView
                Kirigami.StyleHints.showFramedBackground: true
                anchors {
                    top: searchField.bottom
                    topMargin: Kirigami.Units.smallSpacing
                    bottom: leftBottomBar.top
                    bottomMargin: Kirigami.Units.smallSpacing
                    left: parent.left
                    right: parent.right
                }

                ListView {
                    id: connectionView
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: connectionsModel

                    section.property: "section"
                    section.delegate: Kirigami.ListSectionHeader {
                        text: section
                        width: connectionView.width
                    }

                    delegate: QQC2.ItemDelegate {
                        width: connectionView.width
                        highlighted: connectionView.currentIndex === index
                        onClicked: connectionView.currentIndex = index

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: model.icon
                                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                QQC2.Label {
                                    text: model.title
                                    font.weight: model.isConnected ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                QQC2.Label {
                                    text: model.subtitle
                                    font: Kirigami.Theme.smallFont
                                    color: Kirigami.Theme.disabledTextColor
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // Empty Placeholder
                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - (Kirigami.Units.largeSpacing * 2)
                        visible: connectionView.count === 0
                        icon.name: "network-wireless-off"
                        text: searchField.text.length > 0 ? i18n("No matches") : i18n("No available connections")
                    }
                }
            }

            // Bottom Toolbar of Left Panel
            RowLayout {
                id: leftBottomBar
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                spacing: Kirigami.Units.smallSpacing

                QQC2.ToolButton {
                    icon.name: "view-refresh"
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.text: i18n("Scan / Refresh")
                    QQC2.ToolTip.visible: hovered
                    onClicked: {
                        if (typeof kcm !== "undefined") {
                            kcm.refreshStatus();
                            kcm.scanWifi();
                        }
                    }
                }

                QQC2.ToolButton {
                    icon.name: "edit-clear-history"
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.text: i18n("Flush DNS Cache")
                    QQC2.ToolTip.visible: hovered
                    onClicked: {
                        if (typeof kcm !== "undefined") kcm.flushDns();
                    }
                }

                Item { Layout.fillWidth: true }

                QQC2.Switch {
                    id: wifiToggle
                    visible: Boolean(root.wifi && root.wifi.available)
                    checked: Boolean(root.wifi && root.wifi.available)
                    display: QQC2.AbstractButton.IconOnly
                    icon.name: checked ? "network-wireless-on" : "network-wireless-off"
                    QQC2.ToolTip.text: i18n("Enable Wi-Fi")
                    QQC2.ToolTip.visible: hovered
                    onToggled: {
                        const iface = (root.wifi && root.wifi.primary_interface) ? root.wifi.primary_interface : "wlan0";
                        if (typeof kcm !== "undefined") {
                            kcm.executeLinkAction(checked ? "connect" : "disconnect", iface);
                        }
                    }
                }
            }
        }

        // ==========================================
        // RIGHT PANE: Details & Configuration View
        // ==========================================
        Item {
            id: rightPanel
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property var selectedItem: (connectionView.currentIndex >= 0 && connectionView.currentIndex < connectionsModel.count)
                ? connectionsModel.get(connectionView.currentIndex)
                : null

            QQC2.ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: Kirigami.Units.largeSpacing

                    // 1. Connection Header & Actions
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        Layout.topMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.largeSpacing
                        visible: rightPanel.selectedItem !== null

                        Kirigami.Icon {
                            source: rightPanel.selectedItem ? rightPanel.selectedItem.icon : ""
                            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            QQC2.Label {
                                text: rightPanel.selectedItem ? rightPanel.selectedItem.title : ""
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            QQC2.Label {
                                text: {
                                    if (!rightPanel.selectedItem) return "";
                                    const eng = root.backendData.backend || "systemd-networkd";
                                    return rightPanel.selectedItem.statusText + " • " + eng;
                                }
                                color: (rightPanel.selectedItem && rightPanel.selectedItem.isConnected)
                                    ? Kirigami.Theme.positiveTextColor
                                    : Kirigami.Theme.disabledTextColor
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                Layout.fillWidth: true
                            }

                            // Action buttons
                            Flow {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                QQC2.Button {
                                    text: (rightPanel.selectedItem && rightPanel.selectedItem.isConnected) ? i18n("Disconnect") : i18n("Connect")
                                    icon.name: (rightPanel.selectedItem && rightPanel.selectedItem.isConnected) ? "network-disconnect" : "network-connect"
                                    onClicked: {
                                        if (!rightPanel.selectedItem || typeof kcm === "undefined") return;
                                        if (rightPanel.selectedItem.isConnected) {
                                            if (rightPanel.selectedItem.type === "wifi") kcm.disconnectWifi();
                                            else kcm.executeLinkAction("disconnect", rightPanel.selectedItem.name);
                                        } else {
                                            if (rightPanel.selectedItem.type === "wifi") {
                                                if (rightPanel.selectedItem.security && rightPanel.selectedItem.security !== "open" && rightPanel.selectedItem.security !== "none") {
                                                    pwdBox.visible = true;
                                                    wifiPwdInput.forceActiveFocus();
                                                } else {
                                                    kcm.connectWifi(rightPanel.selectedItem.name, "");
                                                }
                                            } else {
                                                kcm.executeLinkAction("connect", rightPanel.selectedItem.name);
                                            }
                                        }
                                    }
                                }

                                QQC2.Button {
                                    text: i18n("Reconfigure")
                                    icon.name: "view-refresh"
                                    visible: rightPanel.selectedItem && rightPanel.selectedItem.isConnected && rightPanel.selectedItem.type === "ethernet"
                                    onClicked: {
                                        if (typeof kcm !== "undefined" && rightPanel.selectedItem) {
                                            kcm.executeLinkAction("reconfigure", rightPanel.selectedItem.name);
                                        }
                                    }
                                }

                                QQC2.Button {
                                    text: i18n("Renew IP")
                                    icon.name: "network-connect"
                                    visible: rightPanel.selectedItem && rightPanel.selectedItem.isConnected && rightPanel.selectedItem.type === "ethernet"
                                    onClicked: {
                                        if (typeof kcm !== "undefined" && rightPanel.selectedItem) {
                                            kcm.executeLinkAction("renew", rightPanel.selectedItem.name);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Inline Wi-Fi Password box if connecting
                    RowLayout {
                        id: pwdBox
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        visible: false
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.TextField {
                            id: wifiPwdInput
                            Layout.fillWidth: true
                            placeholderText: i18n("Enter Wi-Fi Password…")
                            echoMode: showPwdCheck.checked ? TextInput.Normal : TextInput.Password
                            onAccepted: connectBtn.clicked()
                        }

                        QQC2.ToolButton {
                            id: showPwdCheck
                            checkable: true
                            icon.name: checked ? "visibility" : "hint"
                            QQC2.ToolTip.text: i18n("Show password")
                            QQC2.ToolTip.visible: hovered
                        }

                        QQC2.Button {
                            id: connectBtn
                            text: i18n("Connect")
                            icon.name: "network-connect"
                            enabled: wifiPwdInput.text.length >= 8 || (rightPanel.selectedItem && rightPanel.selectedItem.security === "open")
                            onClicked: {
                                if (typeof kcm !== "undefined" && rightPanel.selectedItem) {
                                    kcm.connectWifi(rightPanel.selectedItem.name, wifiPwdInput.text);
                                    wifiPwdInput.text = "";
                                    pwdBox.visible = false;
                                }
                            }
                        }

                        QQC2.Button {
                            text: i18n("Cancel")
                            onClicked: {
                                wifiPwdInput.text = "";
                                pwdBox.visible = false;
                            }
                        }
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        visible: rightPanel.selectedItem !== null
                    }

                    // 2. Details using Kirigami.FormLayout
                    Kirigami.FormLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        visible: rightPanel.selectedItem !== null

                        QQC2.Label {
                            Kirigami.FormData.label: i18n("Interface:")
                            text: rightPanel.selectedItem ? rightPanel.selectedItem.name : ""
                            font.family: "monospace"
                        }

                        QQC2.Label {
                            Kirigami.FormData.label: i18n("Current Speed:")
                            text: rightPanel.selectedItem ? rightPanel.selectedItem.speed_text : ""
                            font.family: "monospace"
                            color: Kirigami.Theme.positiveTextColor
                            visible: rightPanel.selectedItem && rightPanel.selectedItem.isConnected
                        }

                        RowLayout {
                            Kirigami.FormData.label: i18n("IPv4 Address:")
                            visible: rightPanel.selectedItem && Boolean(rightPanel.selectedItem.ipv4_all)
                            spacing: Kirigami.Units.smallSpacing

                            QQC2.Label {
                                text: rightPanel.selectedItem ? rightPanel.selectedItem.ipv4_all : ""
                                font.family: "monospace"
                            }
                            QQC2.ToolButton {
                                icon.name: "edit-copy"
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: i18n("Copy to clipboard")
                                QQC2.ToolTip.visible: hovered
                                onClicked: clipboard.content = rightPanel.selectedItem ? rightPanel.selectedItem.ip : ""
                            }
                        }

                        RowLayout {
                            Kirigami.FormData.label: i18n("Default Gateway:")
                            visible: rightPanel.selectedItem && Boolean(rightPanel.selectedItem.gateway)
                            spacing: Kirigami.Units.smallSpacing

                            QQC2.Label {
                                text: rightPanel.selectedItem ? rightPanel.selectedItem.gateway : ""
                                font.family: "monospace"
                            }
                            QQC2.ToolButton {
                                icon.name: "edit-copy"
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: i18n("Copy to clipboard")
                                QQC2.ToolTip.visible: hovered
                                onClicked: clipboard.content = rightPanel.selectedItem ? rightPanel.selectedItem.gateway : ""
                            }
                        }

                        RowLayout {
                            Kirigami.FormData.label: i18n("DNS Servers:")
                            visible: rightPanel.selectedItem && Boolean(rightPanel.selectedItem.dns)
                            spacing: Kirigami.Units.smallSpacing

                            QQC2.Label {
                                text: rightPanel.selectedItem ? rightPanel.selectedItem.dns : ""
                                font.family: "monospace"
                            }
                            QQC2.ToolButton {
                                icon.name: "edit-copy"
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: i18n("Copy to clipboard")
                                QQC2.ToolTip.visible: hovered
                                onClicked: clipboard.content = rightPanel.selectedItem ? rightPanel.selectedItem.dns : ""
                            }
                        }

                        RowLayout {
                            Kirigami.FormData.label: i18n("Hardware (MAC):")
                            visible: rightPanel.selectedItem && Boolean(rightPanel.selectedItem.mac)
                            spacing: Kirigami.Units.smallSpacing

                            QQC2.Label {
                                text: rightPanel.selectedItem ? rightPanel.selectedItem.mac : ""
                                font.family: "monospace"
                            }
                            QQC2.ToolButton {
                                icon.name: "edit-copy"
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: i18n("Copy to clipboard")
                                QQC2.ToolTip.visible: hovered
                                onClicked: clipboard.content = rightPanel.selectedItem ? rightPanel.selectedItem.mac : ""
                            }
                        }

                        QQC2.Label {
                            Kirigami.FormData.label: i18n("MTU:")
                            text: rightPanel.selectedItem ? rightPanel.selectedItem.mtu.toString() : ""
                            font.family: "monospace"
                            visible: rightPanel.selectedItem && Boolean(rightPanel.selectedItem.mtu)
                        }

                        QQC2.Label {
                            Kirigami.FormData.label: i18n("Security:")
                            text: (rightPanel.selectedItem && rightPanel.selectedItem.security) ? rightPanel.selectedItem.security.toUpperCase() : i18n("Open")
                            visible: rightPanel.selectedItem && rightPanel.selectedItem.type === "wifi"
                        }
                    }

                    // Placeholder when no item is selected
                    Kirigami.PlaceholderMessage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: rightPanel.selectedItem === null
                        icon.name: "preferences-system-network"
                        text: i18n("Select a connection")
                        explanation: i18n("Select a network from the left to view and manage its details.")
                    }
                }
            }
        }
    }
}
