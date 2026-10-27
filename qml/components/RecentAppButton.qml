import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string appName: ""
    property var appIcon: null
    property int windowCount: 1
    property bool active: false

    signal hoveredChanged(bool hovered)
    signal clicked()

    width: 38
    height: 32

    HoverHandler {
        id: hover
        onHoveredChanged: root.hoveredChanged(hovered)
    }

    Rectangle {
        anchors.fill: parent
        radius: 9
        color: root.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                           : (hover.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07) : "transparent")
        border.width: root.active ? 1 : 0
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.34)
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: 16
        height: 16
        source: root.appIcon ? root.appIcon : "application-x-executable"
    }

    Rectangle {
        visible: root.windowCount > 1
        width: 12
        height: 11
        radius: 5
        color: Theme.badgeDark
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 1
        anchors.bottomMargin: 1

        Text {
            anchors.centerIn: parent
            text: root.windowCount
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: 8
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
