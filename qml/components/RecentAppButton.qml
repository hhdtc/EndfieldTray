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

    width: 80
    height: 32

    HoverHandler {
        id: hover
        onHoveredChanged: root.hoveredChanged(hovered)
    }

    Rectangle {
        anchors.fill: parent
        radius: 9
        color: root.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                           : (hover.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.055) : "transparent")
        border.width: root.active ? 1 : 0
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
    }

    Row {
        anchors.centerIn: parent
        spacing: 4

        Kirigami.Icon {
            width: 14
            height: 14
            source: root.appIcon ? root.appIcon : "application-x-executable"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            width: Math.max(0, root.width - 30)
            text: root.appName
            color: root.active ? Theme.accent : Theme.textDim
            font.family: Theme.cjk
            font.pixelSize: 8
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.windowCount > 1
            text: root.windowCount
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: 7
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
