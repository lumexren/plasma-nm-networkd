import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: root

    property var rootItem: null

    readonly property var backendData: (rootItem && rootItem.backendData) ? rootItem.backendData : ({})
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

    Plasmoid.icon: iconName

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
        onClicked: {
            Plasmoid.expanded = !Plasmoid.expanded;
        }
    }
}
