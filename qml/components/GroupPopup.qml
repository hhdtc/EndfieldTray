import QtQuick

Item {
    id: root

    property string appName: ""
    property var windows: []
    property int groupIndex: -1

    signal activated(int windowIndex)
    signal hoveredChanged(bool hovered)

    width: 252
    height: 42 + Math.min(6, Math.max(1, windows.length)) * 28

    HoverHandler {
        id: hover
        onHoveredChanged: root.hoveredChanged(hovered)
    }

    EndfieldFrame {
        anchors.fill: parent
        radius: 12
        accentFrom: 0.04
        accentTo: 0.12
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        anchors.topMargin: 8
        height: 22
        spacing: 6

        Text {
            text: root.appName
            color: Theme.accent
            font.family: Theme.sans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
            width: parent.width - 42
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.windows.length
            color: Theme.textFaint
            font.family: Theme.mono
            font.pixelSize: 8
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    ListView {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 34
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 7
        anchors.leftMargin: 7
        anchors.rightMargin: 7
        clip: true
        model: root.windows
        spacing: 1
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: windowRow
            required property int index
            required property var modelData

            width: ListView.view.width
            height: 27

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: rowMouse.containsMouse
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                    : (modelData.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06) : "transparent")
            }

            Rectangle {
                width: 3
                height: 3
                rotation: 45
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.active ? Theme.accent : Theme.textFaint
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 19
                anchors.right: parent.right
                anchors.rightMargin: 6
                text: modelData.title
                color: modelData.active ? Theme.accent : Theme.textDim
                font.family: Theme.cjk
                font.pixelSize: 9
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activated(windowRow.index)
            }
        }
    }
}
