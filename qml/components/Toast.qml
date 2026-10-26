import QtQuick

Item {
    id: root

    property string message: ""
    property bool success: true
    property bool shown: false

    width: toastRow.implicitWidth + 32
    height: 38
    opacity: shown ? 1 : 0
    visible: opacity > 0
    scale: shown ? 1 : 0.98

    Behavior on opacity { NumberAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.panelAlt.r, Theme.panelAlt.g, Theme.panelAlt.b, 0.98)
        border.width: 1
        border.color: root.success ? Theme.accentDim : Theme.danger
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        color: root.success ? Theme.accent : Theme.danger
    }

    Row {
        id: toastRow
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            width: 5
            height: 5
            rotation: 45
            color: root.success ? Theme.accent : Theme.danger
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.message
            color: Theme.text
            font.family: Theme.cjk
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
