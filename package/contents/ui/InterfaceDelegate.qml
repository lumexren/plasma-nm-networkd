import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Kirigami.AbstractCard {
    id: root

    property var linkData: ({})
    signal requestAction(string action, string linkName)

    readonly property string ifName: linkData.name || ""
    readonly property string ifType: linkData.type || "ether"
    readonly property string ifState: linkData.state || "unknown"
    readonly property var ipv4List: linkData.ipv4 || []
    readonly property var ipv6List: linkData.ipv6 || []
    readonly property string gateway: linkData.gateway || ""
    readonly property var dnsList: linkData.dns || []
    readonly property string macAddr: linkData.mac || ""
    readonly property int mtuVal: linkData.mtu || 1500
    readonly property bool isUp: linkData.up || false

    property bool expanded: false

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        // Main Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: {
                    if (root.ifType === "wlan") return "network-wireless";
                    if (root.ifType === "wireguard" || root.ifType === "vpn") return "network-vpn";
                    if (root.ifType === "bridge") return "network-workgroup";
                    return "network-wired";
                }
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: Kirigami.Units.iconSizes.medium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label {
                        text: root.ifName
                        font.weight: Font.Bold
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
                    }

                    StatusBadge {
                        stateText: root.ifState
                    }
                }

                QQC2.Label {
                    text: {
                        if (root.ipv4List.length > 0) {
                            return root.ipv4List[0] + (root.gateway ? " (GW: " + root.gateway + ")" : "");
                        } else if (!root.isUp) {
                            return "Arayüz kapalı (Down)";
                        } else {
                            return "IP adresi atanmamış";
                        }
                    }
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Quick Up/Down Toggle
            QQC2.ToolButton {
                icon.name: root.isUp ? "network-disconnect" : "network-connect"
                text: root.isUp ? "Kapat" : "Aç"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: root.isUp ? "Arayüzü Kapat (Down)" : "Arayüzü Aç (Up)"
                onClicked: {
                    root.requestAction(root.isUp ? "down" : "up", root.ifName);
                }
            }

            // Expand/Collapse Details
            QQC2.ToolButton {
                icon.name: root.expanded ? "arrow-up" : "arrow-down"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: root.expanded ? "Daha az bilgi" : "Ayrıntıları göster"
                onClicked: root.expanded = !root.expanded
            }
        }

        // Expanded Details Area
        ColumnLayout {
            id: detailsArea
            visible: root.expanded
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing / 2

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            GridLayout {
                columns: 2
                rowSpacing: 4
                columnSpacing: Kirigami.Units.largeSpacing
                Layout.fillWidth: true

                QQC2.Label {
                    text: "MAC Adresi:"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                QQC2.Label {
                    text: root.macAddr || "-"
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }

                QQC2.Label {
                    text: "MTU:"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                QQC2.Label {
                    text: root.mtuVal.toString()
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }

                QQC2.Label {
                    text: "IPv4:"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: root.ipv4List.length > 0
                }
                QQC2.Label {
                    text: root.ipv4List.join(", ")
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: root.ipv4List.length > 0
                }

                QQC2.Label {
                    text: "IPv6:"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: root.ipv6List.length > 0
                }
                QQC2.Label {
                    text: root.ipv6List.join(", ")
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: root.ipv6List.length > 0
                }

                QQC2.Label {
                    text: "Ağ Geçidi (GW):"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: root.gateway.length > 0
                }
                QQC2.Label {
                    text: root.gateway || "-"
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: root.gateway.length > 0
                }

                QQC2.Label {
                    text: "DNS Sunucuları:"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: root.dnsList.length > 0
                }
                QQC2.Label {
                    text: root.dnsList.join(", ")
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: root.dnsList.length > 0
                }
            }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                QQC2.Button {
                    icon.name: "view-refresh"
                    text: "Yeniden Yapılandır (Reconfigure)"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    onClicked: root.requestAction("reconfigure", root.ifName)
                }

                QQC2.Button {
                    icon.name: "network-connect"
                    text: "DHCP Yenile (Renew)"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    onClicked: root.requestAction("renew", root.ifName)
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
