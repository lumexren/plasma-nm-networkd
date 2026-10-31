import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: root

    property var networkData: ({})
    property bool isConnecting: false
    signal connectClicked(string ssid, string password)
    signal disconnectClicked(string ssid)

    readonly property string ssid: networkData.ssid || i18n("Hidden Network")
    readonly property int signalPct: networkData.signal || 50
    readonly property string security: (networkData.security || "open").toLowerCase()
    readonly property bool isSecured: security !== "open" && security !== "none"
    readonly property bool isConnected: networkData.connected || false

    property bool showPasswordInput: false

    readonly property string signalIcon: {
        if (root.signalPct >= 80) return "network-wireless-signal-excellent";
        if (root.signalPct >= 60) return "network-wireless-signal-good";
        if (root.signalPct >= 40) return "network-wireless-signal-ok";
        if (root.signalPct >= 20) return "network-wireless-signal-weak";
        return "network-wireless-signal-none";
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: root.signalIcon
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label {
                        text: root.ssid
                        font.weight: root.isConnected ? Font.Bold : Font.Normal
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        elide: Text.ElideRight
                    }

                    Kirigami.Icon {
                        source: "channel-secure-symbolic"
                        visible: root.isSecured
                        implicitWidth: Kirigami.Units.iconSizes.small * 0.8
                        implicitHeight: Kirigami.Units.iconSizes.small * 0.8
                    }

                    StatusBadge {
                        visible: root.isConnected
                        stateText: "connected"
                    }
                }

                QQC2.Label {
                    text: (root.isSecured ? root.security.toUpperCase() : i18n("Open Network")) + " • " + i18n("%1% Signal", root.signalPct)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            QQC2.Button {
                id: actionBtn
                visible: !root.isConnected && !root.showPasswordInput
                text: i18n("Connect")
                icon.name: "network-connect"
                onClicked: {
                    if (root.isSecured) {
                        root.showPasswordInput = true;
                        pwdField.forceActiveFocus();
                    } else {
                        root.connectClicked(root.ssid, "");
                    }
                }
            }

            QQC2.Button {
                visible: root.isConnected
                text: i18n("Disconnect")
                icon.name: "network-disconnect"
                onClicked: {
                    root.disconnectClicked(root.ssid);
                }
            }
        }

        // Inline Password Entry Row
        RowLayout {
            visible: root.showPasswordInput
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: pwdField
                Layout.fillWidth: true
                placeholderText: i18n("Wi-Fi Password…")
                echoMode: showPasswordCheck.checked ? TextInput.Normal : TextInput.Password
                onAccepted: {
                    if (text.length > 0) {
                        root.connectClicked(root.ssid, text);
                        root.showPasswordInput = false;
                        text = "";
                    }
                }
            }

            QQC2.CheckBox {
                id: showPasswordCheck
                text: i18n("Show")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            QQC2.Button {
                text: i18n("Join")
                icon.name: "dialog-ok-apply"
                enabled: pwdField.text.length >= 8 || !root.isSecured
                onClicked: {
                    root.connectClicked(root.ssid, pwdField.text);
                    root.showPasswordInput = false;
                    pwdField.text = "";
                }
            }

            QQC2.Button {
                text: i18n("Cancel")
                icon.name: "dialog-cancel"
                onClicked: {
                    root.showPasswordInput = false;
                    pwdField.text = "";
                }
            }
        }
    }
}
