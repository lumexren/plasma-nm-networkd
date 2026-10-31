import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.coreaddons as KCoreAddons
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.kirigamiaddons.formcard as FormCard

KCMUtils.SimpleKCM {
    id: root

    KQuickControlsAddons.Clipboard {
        id: clipboard
    }

    readonly property var backendData: kcm.backendData || ({})
    readonly property var links: backendData.links || []
    readonly property var wifi: backendData.wifi || ({ available: false })
    readonly property var wifiNets: kcm.wifiNetworks || []

    // Inline Message
    Kirigami.InlineMessage {
        id: msgBanner
        Layout.fillWidth: true
        visible: kcm.bannerMessage && kcm.bannerMessage.length > 0
        text: kcm.bannerMessage || ""
        type: kcm.bannerIsError ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
        showCloseButton: true
    }

    // 1. GENERAL STATUS & BACKEND INFO
    FormCard.FormHeader {
        title: i18n("Network Status & Backend")
    }

    FormCard.FormCard {
        FormCard.FormTextDelegate {
            text: i18n("Backend Engine")
            description: (backendData.backend || "systemd-networkd") + (backendData.online ? (" • " + i18n("Online")) : (" • " + i18n("Offline")))
            leading: Kirigami.Icon {
                source: backendData.online ? "network-connect" : "network-disconnect"
            }
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormButtonDelegate {
            text: i18n("Flush DNS Resolver Cache")
            description: i18n("Clear local resolved cache entries")
            icon.name: "edit-clear-history"
            onClicked: kcm.flushDns()
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormButtonDelegate {
            text: i18n("Refresh Network Status")
            icon.name: "view-refresh"
            onClicked: {
                kcm.refreshStatus();
                kcm.scanWifi();
            }
        }
    }

    // 2. CONNECTED NETWORKS
    FormCard.FormHeader {
        title: i18n("Connected Networks")
    }

    Repeater {
        model: {
            const res = [];
            for (let i = 0; i < root.links.length; i++) {
                const l = root.links[i];
                if (l.type === "bridge" || l.name === "lo") continue;
                if ((l.state === "routable" || l.state === "connected") && l.ipv4 && l.ipv4.length > 0) {
                    res.push(l);
                }
            }
            return res;
        }

        delegate: FormCard.FormCard {
            Layout.fillWidth: true

            FormCard.FormTextDelegate {
                text: (modelData.type === "ether" ? i18n("Wired Connection (%1)", modelData.name) : modelData.name)
                description: {
                    const rx = modelData.rx_speed || 0;
                    const tx = modelData.tx_speed || 0;
                    return (modelData.ipv4 && modelData.ipv4.length > 0 ? modelData.ipv4[0] : "") +
                           " • " + i18nc("Download and upload rates in some unit per second", "↓ %1/s, ↑ %2/s",
                               KCoreAddons.Format.formatByteSize(rx),
                               KCoreAddons.Format.formatByteSize(tx));
                }
                leading: Kirigami.Icon {
                    source: modelData.type === "wlan" ? "network-wireless-connected-100" : "network-wired-activated"
                }
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormTextDelegate {
                text: i18n("IPv4 Address")
                description: (modelData.ipv4 && modelData.ipv4.join(", ")) || "—"
                trailing: QQC2.ToolButton {
                    icon.name: "edit-copy"
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.text: i18n("Copy to clipboard")
                    QQC2.ToolTip.visible: hovered
                    onClicked: clipboard.content = (modelData.ipv4 && modelData.ipv4[0]) || ""
                }
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormTextDelegate {
                text: i18n("Default Gateway")
                description: modelData.gateway || "—"
                trailing: QQC2.ToolButton {
                    icon.name: "edit-copy"
                    display: QQC2.AbstractButton.IconOnly
                    visible: Boolean(modelData.gateway)
                    QQC2.ToolTip.text: i18n("Copy to clipboard")
                    QQC2.ToolTip.visible: hovered
                    onClicked: clipboard.content = modelData.gateway || ""
                }
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormTextDelegate {
                text: i18n("DNS Servers")
                description: (modelData.dns && modelData.dns.join(", ")) || "—"
                trailing: QQC2.ToolButton {
                    icon.name: "edit-copy"
                    display: QQC2.AbstractButton.IconOnly
                    visible: Boolean(modelData.dns && modelData.dns.length > 0)
                    QQC2.ToolTip.text: i18n("Copy to clipboard")
                    QQC2.ToolTip.visible: hovered
                    onClicked: clipboard.content = (modelData.dns && modelData.dns.join(", ")) || ""
                }
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormTextDelegate {
                text: i18n("Hardware Address (MAC)")
                description: modelData.mac || "—"
                trailing: QQC2.ToolButton {
                    icon.name: "edit-copy"
                    display: QQC2.AbstractButton.IconOnly
                    visible: Boolean(modelData.mac)
                    QQC2.ToolTip.text: i18n("Copy to clipboard")
                    QQC2.ToolTip.visible: hovered
                    onClicked: clipboard.content = modelData.mac || ""
                }
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormButtonDelegate {
                text: i18n("Disconnect")
                icon.name: "network-disconnect"
                onClicked: {
                    if (modelData.type === "wlan") kcm.disconnectWifi();
                    else kcm.executeLinkAction("disconnect", modelData.name);
                }
            }
        }
    }

    // 3. WI-FI NETWORKS (Only shown if Wi-Fi hardware is available)
    FormCard.FormHeader {
        title: i18n("Wi-Fi Networks")
        visible: Boolean(root.wifi && root.wifi.available)
    }

    FormCard.FormCard {
        visible: Boolean(root.wifi && root.wifi.available)

        FormCard.FormSwitchDelegate {
            id: wifiHwSwitch
            text: i18n("Enable Wi-Fi")
            checked: Boolean(root.wifi && root.wifi.available)
            onToggled: {
                const iface = (root.wifi && root.wifi.primary_interface) ? root.wifi.primary_interface : "wlan0";
                kcm.executeLinkAction(checked ? "connect" : "disconnect", iface);
            }
        }

        FormCard.FormDelegateSeparator {}

        FormCard.FormButtonDelegate {
            text: kcm.isScanning ? i18n("Scanning for Wi-Fi Networks…") : i18n("Scan for Wi-Fi Networks")
            icon.name: "view-refresh"
            enabled: !kcm.isScanning
            onClicked: kcm.scanWifi()
        }
    }

    // Wi-Fi Available Networks List
    Repeater {
        model: root.wifiNets

        delegate: FormCard.FormCard {
            Layout.fillWidth: true
            visible: !modelData.connected

            FormCard.FormTextDelegate {
                text: modelData.ssid || i18n("Hidden Network")
                description: (modelData.security ? modelData.security.toUpperCase() : i18n("Open")) + " • %" + (modelData.signal || 50)
                leading: Kirigami.Icon {
                    source: {
                        const sig = modelData.signal || 50;
                        if (sig >= 80) return "network-wireless-signal-excellent";
                        if (sig >= 60) return "network-wireless-signal-good";
                        if (sig >= 40) return "network-wireless-signal-ok";
                        return "network-wireless-signal-weak";
                    }
                }
                trailing: QQC2.Button {
                    text: i18n("Connect")
                    icon.name: "network-connect"
                    onClicked: {
                        if (!modelData.security || modelData.security === "open" || modelData.security === "none") {
                            kcm.connectWifi(modelData.ssid, "");
                        } else {
                            pwdPrompt.targetSsid = modelData.ssid;
                            pwdPrompt.open();
                        }
                    }
                }
            }
        }
    }

    // Password Prompt Dialog
    Kirigami.PromptDialog {
        id: pwdPrompt
        property string targetSsid: ""
        title: i18n("Connect to %1", targetSsid)
        standardButtons: Kirigami.PromptDialog.Ok | Kirigami.PromptDialog.Cancel

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: i18n("Enter Wi-Fi Password:")
            }

            QQC2.TextField {
                id: wifiPwdInput
                Layout.fillWidth: true
                echoMode: TextInput.Password
            }
        }

        onAccepted: {
            kcm.connectWifi(pwdPrompt.targetSsid, wifiPwdInput.text);
            wifiPwdInput.text = "";
        }
    }
}
