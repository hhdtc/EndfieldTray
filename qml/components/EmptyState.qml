import QtQuick

Item {
    id: root

    property string icon: "tray"
    property string title: "NO SIGNAL"
    property string detail: ""

    Column {
        anchors.centerIn: parent
        spacing: 8

        IconGlyph {
            name: root.icon
            width: 30
            height: 30
            color: Theme.textFaint
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: root.title
            color: Theme.textDim
            font.family: Theme.sans
            font.pixelSize: 14
            font.weight: Font.DemiBold
            font.letterSpacing: 2
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: root.detail
            color: Theme.textFaint
            font.family: Theme.cjk
            font.pixelSize: 10
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text.length > 0
        }
    }
}
