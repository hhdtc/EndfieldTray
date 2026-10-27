import QtQuick

Item {
    id: root

    property string icon: ""
    property string text: ""
    property string subtext: ""
    property bool active: false
    property bool warning: false
    property bool charging: false
    property real level: 1
    property int horizontalPadding: 6

    signal clicked()
    signal wheeled(var wheel)

    implicitWidth: Math.max(38, row.implicitWidth + horizontalPadding * 2)
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: 11
        color: root.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                           : (mouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.055) : "transparent")
        border.width: root.active ? 1 : 0
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.34)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        IconGlyph {
            name: root.icon
            width: 14
            height: 14
            level: root.level
            charging: root.charging
            color: root.warning ? Theme.warning : (root.active || mouse.containsMouse ? Theme.accent : Theme.textDim)
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -3

            Text {
                text: root.text
                color: root.warning ? Theme.warning : (root.active ? Theme.accent : Theme.text)
                font.family: Theme.mono
                font.pixelSize: 9
                font.weight: Font.Medium
            }

            Text {
                visible: root.subtext.length > 0
                text: root.subtext
                color: Theme.textFaint
                font.family: Theme.sans
                font.pixelSize: 8
                font.letterSpacing: 0.4
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: wheel => {
            root.wheeled(wheel)
            wheel.accepted = true
        }
    }
}
