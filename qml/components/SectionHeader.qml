import QtQuick

Item {
    id: root

    property string code: ""
    property string title: ""
    property string detail: ""
    property color accentColor: Theme.accent

    implicitHeight: 30

    Row {
        anchors.fill: parent
        spacing: 10

        Text {
            text: root.code
            color: root.accentColor
            font.family: Theme.mono
            font.pixelSize: 8
            font.letterSpacing: 1.1
            anchors.baseline: titleText.baseline
        }

        Text {
            id: titleText
            text: root.title
            color: Theme.text
            font.family: Theme.sans
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4
        }

        Rectangle {
            width: Math.max(12, parent.width - x - detailText.implicitWidth - 24)
            height: 1
            color: Theme.line
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: titleText.right
            anchors.leftMargin: 2
        }

        Text {
            id: detailText
            text: root.detail
            color: Theme.textFaint
            font.family: Theme.mono
            font.pixelSize: 8
            font.letterSpacing: 0.5
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
