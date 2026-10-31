import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property string stateText: "unknown"

    readonly property color badgeColor: {
        const s = stateText.toLowerCase();
        if (s === "routable" || s === "connected" || s === "configured" || s === "active") {
            return Kirigami.Theme.positiveTextColor;
        } else if (s === "degraded" || s === "carrier" || s === "dormant" || s === "configuring") {
            return Kirigami.Theme.neutralTextColor;
        } else if (s === "no-carrier" || s === "down" || s === "off" || s === "inactive") {
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
        text: root.stateText.toUpperCase()
        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
        font.weight: Font.DemiBold
        color: root.badgeColor
    }
}
