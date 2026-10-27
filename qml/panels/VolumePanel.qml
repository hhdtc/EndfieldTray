import QtQuick
import "../components"
import org.kde.kirigami as Kirigami

BasePanel {
    id: root

    panelWidth: 360
    panelHeight: 440
    code: "04"
    title: "音量"
    detail: "AUDIO / OUTPUT"
    opacity: isActive ? 1 : 0
    visible: isActive

    property bool isActive: false
    property real localVolume: System.volume

    onIsActiveChanged: {
        if (isActive) {
            localVolume = System.volume
            System.refreshAudioSinks()
        }
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
                width: parent.width - 90
                text: "OUTPUT  /  " + (System.audioSinkDescription.length > 0 ? System.audioSinkDescription : System.audioBackend)
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 0.5
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: 8; height: 1 }

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
                font.pixelSize: 9
                font.letterSpacing: 0.8
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            width: parent.width
            height: 92

            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                spacing: 7

                Text {
                    id: volumeNumber
                    text: String(Math.round(root.localVolume)).padStart(2, "0")
                    color: System.muted ? Theme.textFaint : Theme.text
                    font.family: Theme.cjk
                    font.pixelSize: 70
                    font.weight: Font.Bold
                }

                Text {
                    text: "%"
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 16
                    anchors.baseline: volumeNumber.baseline
                }
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
            height: 30
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
            height: 18

            Text {
                text: "0"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 70; height: 1 }

            Text {
                text: "100"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            width: parent.width
            height: 112

            Column {
                anchors.fill: parent
                spacing: 4

                Text {
                    text: "OUTPUT DEVICE  /  输出设备"
                    color: Theme.textFaint
                    font.family: Theme.mono
                    font.pixelSize: 8
                    font.letterSpacing: 0.6
                }

                ListView {
                    width: parent.width
                    height: 92
                    clip: true
                    model: System.audioSinks
                    spacing: 1
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: sinkRow
                        required property int index
                        required property var modelData

                        width: ListView.view.width
                        height: 23

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: sinkMouse.containsMouse
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07)
                                : "transparent"
                        }

                        Rectangle {
                            width: 5
                            height: 5
                            rotation: 45
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.active ? Theme.accent : Theme.textFaint
                        }

                        Kirigami.Icon {
                            visible: modelData.icon.length > 0
                            x: 18
                            width: 13
                            height: 13
                            source: modelData.icon
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            x: modelData.icon.length > 0 ? 36 : 20
                            width: parent.width - x - (modelData.active ? 58 : 8)
                            text: modelData.name
                            color: modelData.active ? Theme.accent : Theme.textDim
                            font.family: Theme.cjk
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            visible: modelData.active
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DEFAULT"
                            color: Theme.accent
                            font.family: Theme.mono
                            font.pixelSize: 8
                            font.letterSpacing: 0.5
                        }

                        MouseArea {
                            id: sinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: System.setAudioSink(modelData.id)
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.line
        }

        Row {
            width: parent.width
            height: 34

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
                font.pixelSize: 8
                font.letterSpacing: 0.6
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
