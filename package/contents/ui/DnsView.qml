import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var fullData: ({})
    signal requestFlushDns()
    signal requestServiceAction(string action)

    spacing: Kirigami.Units.largeSpacing

    Kirigami.AbstractCard {
        Layout.fillWidth: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: "services"
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    QQC2.Label {
                        text: "systemd-networkd & resolved Yönetimi"
                        font.weight: Font.Bold
                    }
                    QQC2.Label {
                        text: "Servisleri yeniden başlatın, yapılandırmayı güncelleyin veya DNS önbelleğini boşaltın."
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Button {
                    icon.name: "edit-clear-history"
                    text: "DNS Önbelleğini Temizle"
                    onClicked: root.requestFlushDns()
                }

                QQC2.Button {
                    icon.name: "system-reboot"
                    text: "Networkd Reload"
                    onClicked: root.requestServiceAction("reload")
                }

                QQC2.Button {
                    icon.name: "view-refresh"
                    text: "Networkd Restart"
                    onClicked: root.requestServiceAction("restart")
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    Kirigami.AbstractCard {
        Layout.fillWidth: true
        Layout.fillHeight: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: "Aktif DNS & Ağ Geçitleri Özeti"
                font.weight: Font.Bold
            }

            Kirigami.Separator { Layout.fillWidth: true }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.fullData.links || []

                delegate: ColumnLayout {
                    width: ListView.view.width
                    spacing: 4
                    visible: (modelData.dns && modelData.dns.length > 0) || modelData.gateway

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: "network-server"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                        }
                        QQC2.Label {
                            text: modelData.name
                            font.weight: Font.DemiBold
                        }
                    }

                    RowLayout {
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.largeSpacing

                        ColumnLayout {
                            spacing: 2
                            QQC2.Label {
                                text: "Ağ Geçidi (Default Gateway):"
                                color: Kirigami.Theme.disabledTextColor
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                            QQC2.Label {
                                text: modelData.gateway || "Yok"
                                font.family: "monospace"
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            QQC2.Label {
                                text: "DNS Sunucuları:"
                                color: Kirigami.Theme.disabledTextColor
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                            QQC2.Label {
                                text: (modelData.dns && modelData.dns.length > 0) ? modelData.dns.join(", ") : "Yok"
                                font.family: "monospace"
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }
                    }

                    Item { height: 6 }
                }
            }
        }
    }
}
