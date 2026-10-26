import QtQuick
import QtQuick.Effects

/**
 * Compact rounded technical shell. Flat fill, no outer border and no
 * top-light gradient: the reference HUD is a uniform warm grey pill.
 * Plain rectangles keep this cheap to composite.
 */
Item {
    id: root

    property color fillColor: Theme.panel
    property color borderColor: Theme.line
    property color accentColor: Theme.accent
    property real radius: 18
    property int cut: 0
    property real accentFrom: 0.04
    property real accentTo: 0.10
    property bool hatch: false
    property bool shadow: true
    property bool decorations: true

    RectangularShadow {
        visible: root.shadow
        anchors.fill: parent
        radius: root.radius
        blur: 18
        spread: 1
        color: "#55000000"
        offset: Qt.vector2d(0, 3)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.fillColor
    }

    // Short acid rail at the left edge of the bottom lip.
    Rectangle {
        visible: root.decorations
        x: root.width * root.accentFrom
        y: root.height - 2
        width: Math.max(18, root.width * (root.accentTo - root.accentFrom))
        height: 2
        radius: 1
        color: root.accentColor
    }

    // Registration tick at the opposite end.
    Rectangle {
        visible: root.decorations
        x: root.width - 28
        y: root.height - 4
        width: 12
        height: 2
        radius: 1
        color: Qt.rgba(Theme.textDim.r, Theme.textDim.g, Theme.textDim.b, 0.45)
    }

    Rectangle {
        visible: root.decorations
        x: root.width - 20
        y: 7
        width: 4
        height: 4
        rotation: 45
        color: root.accentColor
        opacity: 0.7
    }
}
