import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property string stateText: "unknown"

    readonly property string localizedText: {
        const s = stateText.toLowerCase();
        if (s === "routable") return i18n("Routable");
        if (s === "connected" || s === "bağlı") return i18n("Connected");
        if (s === "configured") return i18n("Configured");
        if (s === "configuring") return i18n("Configuring");
        if (s === "degraded") return i18n("Degraded");
        if (s === "carrier") return i18n("Carrier");
        if (s === "no-carrier") return i18n("No Carrier");
        if (s === "down" || s === "off") return i18n("Down");
        if (s === "unmanaged") return i18n("Unmanaged");
        if (s === "active") return i18n("Active");
        if (s === "inactive") return i18n("Inactive");
        if (s === "online" || s === "çevrimiçi") return i18n("Online");
        if (s === "offline" || s === "çevrimdışı") return i18n("Offline");
        return stateText;
    }

    readonly property color badgeColor: {
        const s = stateText.toLowerCase();
        if (s === "routable" || s === "connected" || s === "configured" || s === "active" || s === "online" || s === "bağlı" || s === "çevrimiçi") {
            return Kirigami.Theme.positiveTextColor;
        } else if (s === "degraded" || s === "carrier" || s === "dormant" || s === "configuring") {
            return Kirigami.Theme.neutralTextColor;
        } else if (s === "no-carrier" || s === "down" || s === "off" || s === "inactive" || s === "offline" || s === "çevrimdışı") {
            return Kirigami.Theme.negativeTextColor;
        } else {
            return Kirigami.Theme.disabledTextColor;
        }
    }

    implicitWidth: label.implicitWidth + Kirigami.Units.smallSpacing * 3
    implicitHeight: label.implicitHeight + Kirigami.Units.smallSpacing

    radius: height / 2
    color: Qt.rgba(badgeColor.r, badgeColor.g, badgeColor.b, 0.15)
    border.color: Qt.rgba(badgeColor.r, badgeColor.g, badgeColor.b, 0.4)
    border.width: 1

    QQC2.Label {
        id: label
        anchors.centerIn: parent
        text: root.localizedText.toUpperCase()
        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
        font.weight: Font.DemiBold
        color: root.badgeColor
    }
}
