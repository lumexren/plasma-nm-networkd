import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

QQC2.ItemDelegate {
    id: root

    // Generic properties
    property string itemType: "ethernet" // "ethernet", "wifi-connected", "wifi-available", "bridge"
    property string title: ""
    property string subtitle: ""
    property string iconName: "network-wired"
    property bool isConnected: false
    property bool isSecured: false
    property int signalPct: 0

    // Detail properties
    property var details: ({}) // { ipv4: [], gateway: "", dns: [], mac: "", mtu: 1500, ifname: "" }

    // Signals
    signal requestAction(string action, string ifname)
    signal requestConnect(string ssid, string password)
    signal requestDisconnect()

    property bool expanded: false
    property bool showPasswordInput: false

    Layout.fillWidth: true
    implicitWidth: ListView.view ? ListView.view.width : Kirigami.Units.gridUnit * 20
    implicitHeight: mainLayout.implicitHeight + Kirigami.Units.smallSpacing * 2

    contentItem: ColumnLayout {
        id: mainLayout
        spacing: 0

        // Main Clickable Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: root.iconName
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label {
                        text: root.title
                        font.weight: root.isConnected ? Font.Bold : Font.Normal
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        elide: Text.ElideRight
                    }

                    Kirigami.Icon {
                        source: "channel-secure-symbolic"
                        visible: root.isSecured && !root.isConnected
                        implicitWidth: Kirigami.Units.iconSizes.small * 0.75
                        implicitHeight: Kirigami.Units.iconSizes.small * 0.75
                    }
                }

                QQC2.Label {
                    text: root.subtitle
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Right-side indicators and buttons
            RowLayout {
                spacing: 2

                // Connected checkmark icon
                Kirigami.Icon {
                    source: "checkmark"
                    visible: root.isConnected
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    color: Kirigami.Theme.positiveTextColor
                }

                // Connect Button for available Wi-Fi
                QQC2.Button {
                    visible: !root.isConnected && root.itemType === "wifi-available" && !root.showPasswordInput
                    text: i18n("Connect")
                    icon.name: "network-connect"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    onClicked: {
                        if (root.isSecured) {
                            root.showPasswordInput = true;
                            pwdField.forceActiveFocus();
                        } else {
                            root.requestConnect(root.title, "");
                        }
                    }
                }

                // Disconnect Button
                QQC2.ToolButton {
                    visible: root.isConnected
                    icon.name: "network-disconnect"
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18n("Disconnect")
                    onClicked: root.requestDisconnect()
                }

                // Expand details toggle
                QQC2.ToolButton {
                    visible: root.isConnected || root.itemType === "ethernet" || root.itemType === "bridge"
                    icon.name: root.expanded ? "arrow-up" : "arrow-down"
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: root.expanded ? i18n("Show less") : i18n("Details")
                    onClicked: root.expanded = !root.expanded
                }
            }
        }

        // Inline Password Entry for Wi-Fi
        RowLayout {
            visible: root.showPasswordInput
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: pwdField
                Layout.fillWidth: true
                placeholderText: i18n("Wi-Fi Password…")
                echoMode: showPwdCheck.checked ? TextInput.Normal : TextInput.Password
                onAccepted: {
                    if (text.length > 0) {
                        root.requestConnect(root.title, text);
                        root.showPasswordInput = false;
                        text = "";
                    }
                }
            }

            QQC2.CheckBox {
                id: showPwdCheck
                text: i18n("Show")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            QQC2.Button {
                text: i18n("Join")
                icon.name: "dialog-ok-apply"
                enabled: pwdField.text.length >= 8 || !root.isSecured
                onClicked: {
                    root.requestConnect(root.title, pwdField.text);
                    root.showPasswordInput = false;
                    pwdField.text = "";
                }
            }

            QQC2.ToolButton {
                icon.name: "dialog-cancel"
                onClicked: {
                    root.showPasswordInput = false;
                    pwdField.text = "";
                }
            }
        }

        // Expanded Details Accordion (IP, Gateway, DNS, Actions)
        ColumnLayout {
            visible: root.expanded
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.leftMargin: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing
            spacing: 3

            Kirigami.Separator { Layout.fillWidth: true }

            GridLayout {
                columns: 2
                rowSpacing: 2
                columnSpacing: Kirigami.Units.largeSpacing

                QQC2.Label {
                    text: i18n("IPv4:")
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: (root.details.ipv4 && root.details.ipv4.length > 0) || false
                }
                QQC2.Label {
                    text: (root.details.ipv4 && root.details.ipv4.join(", ")) || ""
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: (root.details.ipv4 && root.details.ipv4.length > 0) || false
                }

                QQC2.Label {
                    text: i18n("Gateway:")
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: (root.details.gateway && root.details.gateway.length > 0) || false
                }
                QQC2.Label {
                    text: root.details.gateway || ""
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: (root.details.gateway && root.details.gateway.length > 0) || false
                }

                QQC2.Label {
                    text: i18n("DNS:")
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: (root.details.dns && root.details.dns.length > 0) || false
                }
                QQC2.Label {
                    text: (root.details.dns && root.details.dns.join(", ")) || ""
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: (root.details.dns && root.details.dns.length > 0) || false
                }

                QQC2.Label {
                    text: i18n("MAC Address:")
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: (root.details.mac && root.details.mac.length > 0) || false
                }
                QQC2.Label {
                    text: root.details.mac || ""
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    visible: (root.details.mac && root.details.mac.length > 0) || false
                }
            }

            // Quick Actions Row
            RowLayout {
                Layout.topMargin: 2
                spacing: Kirigami.Units.smallSpacing

                QQC2.Button {
                    text: i18n("Reconfigure")
                    icon.name: "view-refresh"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    onClicked: root.requestAction("reconfigure", root.details.ifname || "")
                }

                QQC2.Button {
                    text: i18n("Renew DHCP")
                    icon.name: "network-connect"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    onClicked: root.requestAction("renew", root.details.ifname || "")
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    onClicked: {
        if (!root.isConnected && root.itemType === "wifi-available") {
            if (root.isSecured) {
                root.showPasswordInput = !root.showPasswordInput;
            } else {
                root.requestConnect(root.title, "");
            }
        } else if (root.isConnected || root.itemType === "ethernet") {
            root.expanded = !root.expanded;
        }
    }
}
