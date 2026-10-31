import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var rootItem: null

    implicitWidth: Kirigami.Units.gridUnit * 28
    implicitHeight: Kirigami.Units.gridUnit * 32

    readonly property var backendData: (rootItem && rootItem.backendData) ? rootItem.backendData : ({})
    readonly property var netStatus: backendData.systemd_networkd || ({})
    readonly property bool isNetworkdActive: netStatus.active || false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // Top Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "network-wired"
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: Kirigami.Units.iconSizes.medium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                QQC2.Label {
                    text: "Systemd Networkd"
                    font.weight: Font.Bold
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                }
                RowLayout {
                    spacing: 4
                    StatusBadge {
                        stateText: root.isNetworkdActive ? "networkd: aktif" : "networkd: pasif"
                    }
                    StatusBadge {
                        visible: root.backendData.online || false
                        stateText: "çevrimiçi"
                    }
                }
            }

            QQC2.ToolButton {
                icon.name: "view-refresh"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: "Durumu Yenile"
                onClicked: if (root.rootItem) root.rootItem.refreshStatus()
            }
        }

        // Inline notification banner for actions/errors
        Kirigami.InlineMessage {
            id: bannerMsg
            Layout.fillWidth: true
            visible: root.rootItem ? (root.rootItem.actionMessage.length > 0) : false
            text: root.rootItem ? root.rootItem.actionMessage : ""
            type: (root.rootItem && root.rootItem.actionIsError) ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
            showCloseButton: true
            onVisibleChanged: {
                if (!visible && root.rootItem) root.rootItem.actionMessage = "";
            }
        }

        // Category Tabs
        QQC2.TabBar {
            id: tabBar
            Layout.fillWidth: true

            QQC2.TabButton {
                text: "Arayüzler"
                icon.name: "network-wired"
            }
            QQC2.TabButton {
                text: "Wi-Fi"
                icon.name: "network-wireless"
                visible: root.backendData.wifi && root.backendData.wifi.available
            }
            QQC2.TabButton {
                text: "DNS & Sistem"
                icon.name: "network-server"
            }
        }

        // Stacked View Content
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // TAB 1: INTERFACES LIST
            Item {
                id: interfacesTab

                QQC2.ScrollView {
                    anchors.fill: parent
                    clip: true

                    ListView {
                        id: ifacesList
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing
                        model: root.backendData.links || []

                        delegate: InterfaceDelegate {
                            width: ifacesList.width
                            linkData: modelData
                            onRequestAction: (action, linkName) => {
                                if (root.rootItem) root.rootItem.executeLinkAction(action, linkName);
                            }
                        }
                    }
                }
            }

            // TAB 2: WI-FI
            Item {
                id: wifiTab

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    // Wi-Fi Header / Scan Button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            text: {
                                const w = root.backendData.wifi;
                                if (!w) return "";
                                return "Kart: " + (w.primary_interface || "") + " (" + (w.backend || "iwd") + ")";
                            }
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: Kirigami.Theme.disabledTextColor
                            Layout.fillWidth: true
                        }

                        QQC2.BusyIndicator {
                            running: root.rootItem ? root.rootItem.isScanningWifi : false
                            visible: running
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                        }

                        QQC2.Button {
                            text: "Ağları Tara"
                            icon.name: "network-wireless"
                            enabled: root.rootItem ? !root.rootItem.isScanningWifi : true
                            onClicked: if (root.rootItem) root.rootItem.scanWifi()
                        }
                    }

                    Kirigami.Separator { Layout.fillWidth: true }

                    // Wi-Fi Networks List
                    QQC2.ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            id: wifiList
                            width: parent.width
                            spacing: Kirigami.Units.smallSpacing
                            model: root.rootItem ? root.rootItem.wifiNetworks : []

                            delegate: WifiDelegate {
                                width: wifiList.width
                                networkData: modelData
                                onConnectClicked: (ssid, password) => {
                                    if (root.rootItem) root.rootItem.connectWifi(ssid, password);
                                }
                                onDisconnectClicked: (ssid) => {
                                    if (root.rootItem) root.rootItem.disconnectWifi();
                                }
                            }

                            QQC2.Label {
                                anchors.centerIn: parent
                                text: (root.rootItem && root.rootItem.isScanningWifi) ? "Kablosuz ağlar taranıyor..." : "Ağ bulunamadı veya henüz taranmadı.\nYukarıdaki 'Ağları Tara' butonuna basın."
                                horizontalAlignment: Text.AlignHCenter
                                color: Kirigami.Theme.disabledTextColor
                                visible: wifiList.count === 0
                            }
                        }
                    }
                }
            }

            // TAB 3: DNS & SYSTEM
            DnsView {
                fullData: root.backendData
                onRequestFlushDns: if (root.rootItem) root.rootItem.flushDns()
                onRequestServiceAction: (action) => {
                    if (root.rootItem) root.rootItem.executeServiceAction(action);
                }
            }
        }
    }
}
