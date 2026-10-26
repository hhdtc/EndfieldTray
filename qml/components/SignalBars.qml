import QtQuick

Item {
    id: root

    property int strength: 0
    property color color: Theme.textDim
    property color activeColor: Theme.accent
    property real barWidth: 2
    property real gap: 2

    implicitWidth: 3 * barWidth + 2 * gap
    implicitHeight: 14

    Row {
        anchors.bottom: parent.bottom
        spacing: root.gap

        Repeater {
            model: [4, 7, 10, 13]

            Rectangle {
                required property int index
                required property int modelData
                width: root.barWidth
                height: modelData
                anchors.bottom: parent.bottom
                color: root.strength >= (index + 1) * 22 ? root.activeColor : Qt.rgba(root.color.r, root.color.g, root.color.b, 0.35)
            }
        }
    }
}
