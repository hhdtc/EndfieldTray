import QtQuick

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property string trailing: ""
    property bool active: false
    property bool accent: false
    property bool showChevron: false
    property int horizontalPadding: 8

    signal clicked()
    signal wheeled(var wheel)

    implicitWidth: content.implicitWidth + horizontalPadding * 2
    implicitHeight: 38

    Rectangle {
        anchors.fill: parent
        radius: 13
        color: root.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                           : (mouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.055) : "transparent")
        border.width: root.active ? 1 : 0
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.34)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        IconGlyph {
            visible: root.icon.length > 0
            name: root.icon
            width: 15
            height: 15
            color: root.active || root.accent ? Theme.accent : Theme.textDim
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            Text {
                text: root.label
                color: root.active || root.accent ? Theme.accent : Theme.text
                font.family: Theme.sans
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.7
                visible: text.length > 0
            }

            Text {
                text: root.sublabel
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 7
                visible: text.length > 0
            }
        }

        Text {
            visible: root.trailing.length > 0
            text: root.trailing
            color: root.accent ? Theme.accent : Theme.textFaint
            font.family: Theme.mono
            font.pixelSize: 8
            anchors.verticalCenter: parent.verticalCenter
        }

        IconGlyph {
            visible: root.showChevron
            name: "chevron"
            width: 9
            height: 9
            color: Theme.textFaint
            anchors.verticalCenter: parent.verticalCenter
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
