import QtQuick

Item {
    id: root

    property int panelWidth: 400
    property int panelHeight: 340
    property string code: "00"
    property string title: "PANEL"
    property string detail: ""
    property bool showClose: true

    default property alias content: body.data

    signal closeRequested()

    width: panelWidth
    height: panelHeight
    // Render panels at native scale. Scaling an Item resamples the glyph
    // rasters and makes small text look soft under fractional DPI scaling.
    opacity: 0

    Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    EndfieldFrame {
        anchors.fill: parent
        radius: 16
        accentFrom: 0.03
        accentTo: 0.08
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 38
        width: 1
        height: Math.max(0, parent.height - 56)
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        anchors.topMargin: 10
        height: 22

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Text {
                text: root.code
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: 8
                anchors.baseline: titleText.baseline
            }

            Text {
                id: titleText
                text: root.title
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4
            }

            Rectangle {
                width: 1
                height: 10
                color: Theme.lineBright
                anchors.verticalCenter: parent.verticalCenter
                visible: root.detail.length > 0
            }

            Text {
                text: root.detail
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 8
                font.letterSpacing: 0.5
                anchors.verticalCenter: parent.verticalCenter
                visible: text.length > 0
            }
        }

        Item {
            visible: root.showClose
            width: 22
            height: 22
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: closeMouse.containsMouse ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.12) : "transparent"
            }

            IconGlyph {
                anchors.centerIn: parent
                name: "close"
                width: 11
                height: 11
                color: closeMouse.containsMouse ? Theme.danger : Theme.textDim
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.top: header.bottom
        anchors.topMargin: 4
        height: 1
        color: Theme.line
    }

    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 17
        anchors.rightMargin: 15
        anchors.topMargin: 12
        anchors.bottomMargin: 12
    }
}
