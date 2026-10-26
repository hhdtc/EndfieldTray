import QtQuick

Item {
    id: root

    property string label: ""
    property bool accent: false
    property bool interactive: true
    property string icon: ""

    signal clicked()

    implicitWidth: Math.max(62, content.implicitWidth + 24)
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.accent
            ? (mouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.92) : Theme.accent)
            : (mouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10) : Qt.rgba(0, 0, 0, 0.10))
        border.width: 1
        border.color: root.accent ? Theme.accent : (mouse.containsMouse ? Theme.accentDim : Theme.lineBright)
        opacity: root.interactive ? 1 : 0.4
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        IconGlyph {
            visible: root.icon.length > 0
            name: root.icon
            width: 12
            height: 12
            color: root.accent ? Theme.bg : Theme.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.label
            color: root.accent ? Theme.bg : Theme.text
            font.family: Theme.sans
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 0.9
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
