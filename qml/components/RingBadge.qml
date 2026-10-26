import QtQuick

Item {
    id: root

    property real value: 0
    property string icon: ""
    property bool active: false
    property bool warning: false
    property bool charging: false
    property real startAngle: -Math.PI / 2
    property bool hovered: mouse.containsMouse

    signal clicked()
    signal wheeled(var wheel)

    onValueChanged: canvas.requestPaint()
    onActiveChanged: canvas.requestPaint()
    onWarningChanged: canvas.requestPaint()

    implicitWidth: 34
    implicitHeight: 34

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            const s = Math.min(width, height)
            const c = s / 2
            const r = c - 3.0
            ctx.reset()

            ctx.beginPath()
            ctx.arc(c, c, r, 0, Math.PI * 2)
            ctx.fillStyle = root.active
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                : Theme.badgeDark
            ctx.fill()

            ctx.beginPath()
            ctx.arc(c, c, r, 0, Math.PI * 2)
            ctx.lineWidth = 2.6
            ctx.strokeStyle = Qt.rgba(Theme.line.r, Theme.line.g, Theme.line.b, 0.72)
            ctx.stroke()

            const clamped = Math.max(0, Math.min(1, root.value))
            if (clamped > 0.01) {
                ctx.beginPath()
                ctx.arc(c, c, r, root.startAngle, root.startAngle + Math.PI * 2 * clamped)
                ctx.lineWidth = 2.9
                ctx.lineCap = "round"
                ctx.strokeStyle = root.warning ? Theme.warning : Theme.accent
                ctx.stroke()
            }
        }
    }

    IconGlyph {
        anchors.centerIn: parent
        width: 15
        height: 15
        name: root.icon
        charging: root.charging
        level: root.value
        color: root.warning ? Theme.warning : Theme.accent
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
        onContainsMouseChanged: canvas.requestPaint()
    }
}
