import QtQuick

/**
 * Compact rounded technical shell. Plain rectangles keep this cheap to
 * composite and avoid any continuously animating layers.
 */
Item {
    id: root

    property color fillColor: Qt.rgba(Theme.panel.r, Theme.panel.g, Theme.panel.b, 0.97)
    property color borderColor: Theme.line
    property color accentColor: Theme.accent
    property real radius: 18
    property int cut: 0
    property real accentFrom: 0.04
    property real accentTo: 0.10
    property bool hatch: false
    property bool shadow: true
    property bool decorations: true

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.fillColor
        border.width: 1
        border.color: root.borderColor
    }

    // Gentle top-light gradient; no animation, no offscreen layer.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(255, 255, 255, 0.035) }
            GradientStop { position: 0.30; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.16) }
        }
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
