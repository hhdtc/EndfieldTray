import QtQuick

/**
 * A small set of line glyphs drawn in a 24x24 coordinate system. Keeping these
 * in Canvas means every icon shares the same stroke width and can follow the
 * accent color on hover without SVG recoloring tricks.
 */
Canvas {
    id: root

    property string name: ""
    property color color: Theme.text
    property color accentColor: Theme.accent
    property real lineWidth: 1.7
    property real level: 0.7
    property bool charging: false

    implicitWidth: 20
    implicitHeight: 20
    antialiasing: true

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onAccentColorChanged: requestPaint()
    onLevelChanged: requestPaint()
    onChargingChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Component.onCompleted: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        if (width <= 0 || height <= 0)
            return

        const scale = Math.min(width, height) / 24
        ctx.save()
        ctx.scale(scale, scale)
        ctx.translate((width / scale - 24) / 2, (height / scale - 24) / 2)
        ctx.strokeStyle = root.color
        ctx.fillStyle = root.color
        ctx.lineWidth = root.lineWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        switch (root.name) {
        case "bluetooth":
            ctx.beginPath()
            ctx.moveTo(12, 3)
            ctx.lineTo(17, 8)
            ctx.lineTo(7, 18)
            ctx.moveTo(12, 3)
            ctx.lineTo(7, 8)
            ctx.lineTo(17, 18)
            ctx.moveTo(12, 3)
            ctx.lineTo(12, 21)
            ctx.stroke()
            break

        case "wifi":
            for (const r of [9.5, 6.4, 3.2]) {
                ctx.beginPath()
                ctx.arc(12, 18.5, r, Math.PI * 1.24, Math.PI * 1.76)
                ctx.stroke()
            }
            ctx.beginPath()
            ctx.arc(12, 18.5, 1.15, 0, Math.PI * 2)
            ctx.fill()
            break

        case "wifi-off":
            ctx.beginPath()
            ctx.arc(12, 18.5, 9.5, Math.PI * 1.24, Math.PI * 1.58)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(12, 18.5, 5.8, Math.PI * 1.24, Math.PI * 1.6)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(4, 4)
            ctx.lineTo(20, 20)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(12, 18.5, 1.15, 0, Math.PI * 2)
            ctx.fill()
            break

        case "ethernet":
            ctx.strokeRect(3.5, 8.5, 17, 10)
            ctx.beginPath()
            ctx.moveTo(7, 4)
            ctx.lineTo(7, 8.5)
            ctx.moveTo(12, 3)
            ctx.lineTo(12, 8.5)
            ctx.moveTo(17, 4)
            ctx.lineTo(17, 8.5)
            ctx.stroke()
            break

        case "volume":
            ctx.beginPath()
            ctx.moveTo(3, 9.2)
            ctx.lineTo(7.2, 9.2)
            ctx.lineTo(12.2, 5)
            ctx.lineTo(12.2, 19)
            ctx.lineTo(7.2, 14.8)
            ctx.lineTo(3, 14.8)
            ctx.closePath()
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(13, 12, 4.4, -0.72, 0.72)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(13, 12, 7.2, -0.62, 0.62)
            ctx.stroke()
            break

        case "volume-mute":
            ctx.beginPath()
            ctx.moveTo(3, 9.2)
            ctx.lineTo(7.2, 9.2)
            ctx.lineTo(12.2, 5)
            ctx.lineTo(12.2, 19)
            ctx.lineTo(7.2, 14.8)
            ctx.lineTo(3, 14.8)
            ctx.closePath()
            ctx.stroke()
            ctx.strokeStyle = root.accentColor
            ctx.beginPath()
            ctx.moveTo(15, 9)
            ctx.lineTo(21, 15)
            ctx.moveTo(21, 9)
            ctx.lineTo(15, 15)
            ctx.stroke()
            break

        case "battery":
        case "battery-charging": {
            ctx.strokeRect(2.5, 7, 17, 10)
            ctx.beginPath()
            ctx.moveTo(21.5, 10)
            ctx.lineTo(21.5, 14)
            ctx.stroke()
            const fillWidth = Math.max(0, Math.min(1, root.level)) * 13
            ctx.fillStyle = root.level <= 0.18 ? Theme.danger : (root.charging ? root.accentColor : root.color)
            ctx.globalAlpha = 0.82
            ctx.fillRect(4.2, 8.7, fillWidth, 6.6)
            ctx.globalAlpha = 1
            if (root.charging) {
                ctx.fillStyle = Theme.bg
                ctx.beginPath()
                ctx.moveTo(12.4, 8.4)
                ctx.lineTo(9.2, 12.4)
                ctx.lineTo(11.5, 12.4)
                ctx.lineTo(10.5, 15.7)
                ctx.lineTo(14.4, 11.4)
                ctx.lineTo(12, 11.4)
                ctx.closePath()
                ctx.fill()
            }
            break
        }

        case "brightness":
            ctx.beginPath()
            ctx.arc(12, 12, 3.7, 0, Math.PI * 2)
            ctx.stroke()
            for (let i = 0; i < 8; ++i) {
                const angle = i * Math.PI / 4
                ctx.beginPath()
                ctx.moveTo(12 + Math.cos(angle) * 6.4, 12 + Math.sin(angle) * 6.4)
                ctx.lineTo(12 + Math.cos(angle) * 8.8, 12 + Math.sin(angle) * 8.8)
                ctx.stroke()
            }
            break

        case "keyboard":
            ctx.strokeRect(2.5, 7.5, 19, 9)
            ctx.beginPath()
            ctx.moveTo(5.5, 10.5)
            ctx.lineTo(18.5, 10.5)
            ctx.moveTo(5.5, 13.2)
            ctx.lineTo(15.5, 13.2)
            ctx.stroke()
            break

        case "power":
            ctx.beginPath()
            ctx.arc(12, 12.4, 7.2, Math.PI * -0.34, Math.PI * 1.34)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(12, 2.8)
            ctx.lineTo(12, 11.2)
            ctx.stroke()
            break

        case "sleep":
            // Filled crescent: outer left half plus reversed inner half.
            ctx.beginPath()
            ctx.arc(12, 12, 7.2, Math.PI * 0.5, Math.PI * 1.5, false)
            ctx.arc(12, 12, 3.4, Math.PI * 1.5, Math.PI * 0.5, true)
            ctx.closePath()
            ctx.fillStyle = root.color
            ctx.fill()
            break

        case "reboot":
            ctx.beginPath()
            ctx.arc(12, 12.5, 7.2, Math.PI * 0.32, Math.PI * 1.86)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(18.4, 4.8)
            ctx.lineTo(18.8, 9.8)
            ctx.lineTo(14.1, 9.7)
            ctx.stroke()
            break

        case "shutdown":
            ctx.beginPath()
            ctx.arc(12, 12.4, 7.2, Math.PI * -0.34, Math.PI * 1.34)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(12, 2.8)
            ctx.lineTo(12, 11.2)
            ctx.stroke()
            break

        case "logout":
            ctx.beginPath()
            ctx.moveTo(11.5, 3.5)
            ctx.lineTo(4, 3.5)
            ctx.lineTo(4, 20.5)
            ctx.lineTo(11.5, 20.5)
            ctx.stroke()
            ctx.strokeStyle = root.accentColor
            ctx.beginPath()
            ctx.moveTo(10, 12)
            ctx.lineTo(21, 12)
            ctx.moveTo(17.2, 8.2)
            ctx.lineTo(21, 12)
            ctx.lineTo(17.2, 15.8)
            ctx.stroke()
            break

        case "lock":
            ctx.strokeRect(5, 10.5, 14, 10)
            ctx.beginPath()
            ctx.arc(12, 10.5, 4.6, Math.PI, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(12, 15.5, 1.1, 0, Math.PI * 2)
            ctx.fill()
            break

        case "windows":
            ctx.strokeRect(3, 4.5, 8, 6.2)
            ctx.strokeRect(13, 4.5, 8, 6.2)
            ctx.strokeRect(3, 13.3, 8, 6.2)
            ctx.strokeStyle = root.accentColor
            ctx.strokeRect(13, 13.3, 8, 6.2)
            break

        case "tray":
            for (const p of [[5, 5], [12, 5], [19, 5], [5, 12], [12, 12], [19, 12], [5, 19], [12, 19], [19, 19]]) {
                ctx.beginPath()
                ctx.arc(p[0], p[1], 1.05, 0, Math.PI * 2)
                ctx.fill()
            }
            break

        case "more":
            for (const x of [6, 12, 18]) {
                ctx.beginPath()
                ctx.arc(x, 12, 1.25, 0, Math.PI * 2)
                ctx.fill()
            }
            break

        case "close":
            ctx.beginPath()
            ctx.moveTo(6, 6)
            ctx.lineTo(18, 18)
            ctx.moveTo(18, 6)
            ctx.lineTo(6, 18)
            ctx.stroke()
            break

        case "chevron":
            ctx.beginPath()
            ctx.moveTo(9, 5)
            ctx.lineTo(16, 12)
            ctx.lineTo(9, 19)
            ctx.stroke()
            break

        case "chevron-left":
            ctx.beginPath()
            ctx.moveTo(15, 5)
            ctx.lineTo(8, 12)
            ctx.lineTo(15, 19)
            ctx.stroke()
            break

        case "check":
            ctx.strokeStyle = root.accentColor
            ctx.beginPath()
            ctx.moveTo(4.5, 12.3)
            ctx.lineTo(9.7, 17.4)
            ctx.lineTo(19.5, 6.6)
            ctx.stroke()
            break

        case "refresh":
            ctx.beginPath()
            ctx.arc(12, 12, 7.2, Math.PI * 0.25, Math.PI * 1.72)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(18.8, 5.2)
            ctx.lineTo(19.2, 10.3)
            ctx.lineTo(14.3, 10.2)
            ctx.stroke()
            break

        case "search":
            ctx.beginPath()
            ctx.arc(10.5, 10.5, 6.2, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(15.2, 15.2)
            ctx.lineTo(21, 21)
            ctx.stroke()
            break

        case "bolt":
            ctx.fillStyle = root.accentColor
            ctx.beginPath()
            ctx.moveTo(13.5, 2.5)
            ctx.lineTo(5.8, 13.5)
            ctx.lineTo(11.2, 13.5)
            ctx.lineTo(9.8, 21.5)
            ctx.lineTo(18.2, 9.8)
            ctx.lineTo(12.4, 9.8)
            ctx.closePath()
            ctx.fill()
            break

        case "diamond":
            ctx.strokeStyle = root.accentColor
            ctx.beginPath()
            ctx.moveTo(12, 2)
            ctx.lineTo(22, 12)
            ctx.lineTo(12, 22)
            ctx.lineTo(2, 12)
            ctx.closePath()
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(12, 7)
            ctx.lineTo(17, 12)
            ctx.lineTo(12, 17)
            ctx.lineTo(7, 12)
            ctx.closePath()
            ctx.fill()
            break

        default:
            ctx.beginPath()
            ctx.arc(12, 12, 7, 0, Math.PI * 2)
            ctx.stroke()
            break
        }

        ctx.restore()
    }
}
