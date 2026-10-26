import QtQuick

Item {
    id: root

    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property color accentColor: Theme.accent
    property bool interactive: true

    signal moved(real value)

    implicitHeight: 42

    function clamp(v) {
        return Math.max(root.from, Math.min(root.to, v))
    }

    function valueAt(x) {
        const ratio = Math.max(0, Math.min(1, (x - 7) / Math.max(1, track.width - 14)))
        return root.clamp(root.from + ratio * (root.to - root.from))
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 3
        color: Theme.line
    }

    Rectangle {
        anchors.left: track.left
        anchors.leftMargin: 7
        anchors.verticalCenter: track.verticalCenter
        width: Math.max(0, (track.width - 14) * (root.value - root.from) / Math.max(1, root.to - root.from))
        height: 3
        color: root.accentColor
    }

    // Technical tick rail.
    Item {
        id: ticks
        x: 7
        width: Math.max(0, track.width - 14)
        height: 5
        anchors.top: track.bottom
        anchors.topMargin: 5

        Repeater {
            model: 21

            Rectangle {
                required property int index
                x: index * (ticks.width / 20)
                width: 1
                height: index % 5 === 0 ? 5 : 2
                color: index % 5 === 0 ? Theme.lineBright : Theme.line
                anchors.bottom: parent.bottom
            }
        }
    }

    Rectangle {
        id: handle
        x: 7 + Math.max(0, (track.width - 14) * (root.value - root.from) / Math.max(1, root.to - root.from)) - width / 2
        width: 12
        height: 12
        rotation: 45
        color: root.accentColor
        anchors.verticalCenter: parent.verticalCenter
        border.width: 2
        border.color: Theme.bg

        Rectangle {
            anchors.centerIn: parent
            width: 4
            height: 4
            color: Theme.bg
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            root.value = root.valueAt(mouse.x)
            root.moved(root.value)
        }
        onPositionChanged: mouse => {
            if (pressed) {
                root.value = root.valueAt(mouse.x)
                root.moved(root.value)
            }
        }
        onWheel: wheel => {
            const delta = wheel.angleDelta.y > 0 ? root.stepSize * 2 : -root.stepSize * 2
            root.value = root.clamp(root.value + delta)
            root.moved(root.value)
            wheel.accepted = true
        }
    }
}
