import QtQuick
import "../components"

BasePanel {
    id: root

    panelWidth: 340
    panelHeight: 360
    code: "04"
    title: "音量"
    detail: "AUDIO / OUTPUT"
    opacity: isActive ? 1 : 0
    visible: isActive

    property bool isActive: false
    property real localVolume: System.volume

    onIsActiveChanged: {
        if (isActive)
            localVolume = System.volume
    }

    Connections {
        target: System
        function onVolumeChanged() {
            root.localVolume = System.volume
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            height: 26

            Text {
                text: "DEFAULT SINK  /  " + System.audioBackend
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 8
                font.letterSpacing: 0.8
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 210; height: 1 }

            IconGlyph {
                name: System.muted ? "volume-mute" : "volume"
                width: 16
                height: 16
                color: System.muted ? Theme.warning : Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: System.muted ? "MUTED" : "LIVE"
                color: System.muted ? Theme.warning : Theme.accent
                font.family: Theme.mono
                font.pixelSize: 8
                font.letterSpacing: 0.8
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            width: parent.width
            height: 116

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: String(Math.round(root.localVolume)).padStart(2, "0")
                color: System.muted ? Theme.textFaint : Theme.text
                font.family: Theme.sans
                font.pixelSize: 86
                font.weight: Font.Bold
                font.letterSpacing: -2
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Math.round(root.localVolume) >= 100 ? 140 : 94
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                text: "%"
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: 16
            }

            // Level meter, purely decorative but tied to the real volume.
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                spacing: 3

                Repeater {
                    model: 14

                    Rectangle {
                        required property int index
                        width: 3
                        height: 10 + ((index * 7) % 34)
                        color: (index / 14.0) <= (root.localVolume / 100.0)
                            ? (index > 11 ? Theme.warning : Theme.accent)
                            : Theme.line
                        opacity: System.muted ? 0.25 : 1
                    }
                }
            }
        }

        EndfieldSlider {
            id: slider
            width: parent.width
            height: 34
            from: 0
            to: 100
            value: root.localVolume
            stepSize: 1
            onMoved: value => {
                root.localVolume = value
                System.setVolume(Math.round(value))
            }
        }

        Row {
            width: parent.width
            height: 30

            Text {
                text: "0"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 8
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 70; height: 1 }

            Text {
                text: "100"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 8
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.line
        }

        Row {
            width: parent.width
            height: 38

            ChamferButton {
                label: System.muted ? "取消静音" : "静音"
                icon: System.muted ? "volume" : "volume-mute"
                accent: System.muted
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    System.toggleMute()
                    root.localVolume = System.volume
                }
            }

            Item { width: parent.width - 260; height: 1 }

            Text {
                text: "WHEEL  /  FINE ADJUST"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 7
                font.letterSpacing: 0.6
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
