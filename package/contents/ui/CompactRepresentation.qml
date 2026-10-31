import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: root

    property PlasmoidItem plasmoidItem: null

    Layout.minimumWidth: Kirigami.Units.iconSizes.small
    Layout.minimumHeight: Kirigami.Units.iconSizes.small

    readonly property var backendData: (plasmoidItem && plasmoidItem.backendData) ? plasmoidItem.backendData : ({})
    readonly property bool isOnline: backendData.online || false
    readonly property string activeLink: backendData.active_link || ""
    readonly property var activeLinkObj: {
        const links = backendData.links || [];
        for (let i = 0; i < links.length; i++) {
            if (links[i].name === activeLink) return links[i];
        }
        return null;
    }

    readonly property string iconName: {
        if (!isOnline) {
            return "network-offline";
        }
        if (activeLinkObj && activeLinkObj.type === "wlan") {
            const wifi = backendData.wifi;
            const sig = (wifi && wifi.connected) ? wifi.connected.signal : 60;
            if (sig >= 80) return "network-wireless-connected-100";
            if (sig >= 60) return "network-wireless-connected-75";
            if (sig >= 40) return "network-wireless-connected-50";
            return "network-wireless-connected-25";
        } else if (activeLinkObj && (activeLinkObj.type === "wireguard" || activeLinkObj.type === "vpn")) {
            return "network-vpn";
        } else {
            return "network-wired-activated";
        }
    }

    Kirigami.Icon {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing / 2
        source: root.iconName
        active: mouseArea.containsMouse
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        property bool wasExpanded: false

        onPressed: mouse => {
            if (root.plasmoidItem) {
                wasExpanded = root.plasmoidItem.expanded;
            } else if (typeof Plasmoid !== "undefined") {
                wasExpanded = Plasmoid.expanded;
            }
        }

        onClicked: mouse => {
            if (root.plasmoidItem) {
                root.plasmoidItem.expanded = !wasExpanded;
            } else if (typeof Plasmoid !== "undefined") {
                Plasmoid.expanded = !Plasmoid.expanded;
            }
        }
    }
}
