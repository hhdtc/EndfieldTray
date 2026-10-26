import QtQuick
import "../components"

BasePanel {
    id: root

    panelWidth: 390
    panelHeight: 410
    code: "05"
    title: "电池"
    detail: "ENERGY / BATTERY"
    opacity: isActive ? 1 : 0
    visible: isActive

    property bool isActive: false
    onIsActiveChanged: {
        if (isActive)
            System.refreshPowerProfile()
    }
    readonly property real fraction: System.batteryPercent / 100.0
    readonly property color levelColor: System.batteryPercent <= 18 ? Theme.danger : (System.charging ? Theme.accent : Theme.text)


    Column {
        anchors.fill: parent
        spacing: 9
        visible: System.batteryPresent

        Row {
            width: parent.width
            height: 28

            Text {
                text: "BAT0  /  " + (System.charging ? "CHARGING" : (System.onAc ? "AC CONNECTED" : "DISCHARGING"))
                color: System.charging ? Theme.accent : Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 8
                font.letterSpacing: 0.8
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 220; height: 1 }

            Rectangle {
                width: 6
                height: 6
                rotation: 45
                color: System.onAc ? Theme.accent : Theme.textFaint
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: System.onAc ? "AC POWER" : "BATTERY"
                color: System.onAc ? Theme.accent : Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 7
                font.letterSpacing: 0.8
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            width: parent.width
            height: 98

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -2
                text: String(System.batteryPercent).padStart(2, "0")
                color: root.levelColor
                font.family: Theme.sans
                font.pixelSize: 82
                font.weight: Font.Bold
                font.letterSpacing: -2
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: System.batteryPercent >= 100 ? 134 : 89
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                text: "%"
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: 16
            }

            Column {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 15
                spacing: 3

                Text {
                    text: System.charging ? "CHARGING" : (System.onAc ? "EXTERNAL POWER" : "ON BATTERY")
                    color: System.charging ? Theme.accent : Theme.textDim
                    font.family: Theme.mono
                    font.pixelSize: 8
                    font.letterSpacing: 0.8
                    anchors.right: parent.right
                }

                Text {
                    text: System.batteryTime.length > 0 ? (System.charging ? "TO FULL  " : "REMAINING  ") + System.batteryTime : "TIME  --"
                    color: Theme.textFaint
                    font.family: Theme.mono
                    font.pixelSize: 8
                    anchors.right: parent.right
                }
            }
        }

        // Segmented energy gauge.
        Row {
            width: parent.width
            height: 18
            spacing: 3

            Repeater {
                model: 24

                Rectangle {
                    required property int index
                    width: (parent.width - 23 * 3) / 24
                    height: 18
                    color: (index / 24.0) <= root.fraction
                        ? (System.batteryPercent <= 18 ? Theme.danger : (System.charging ? Theme.accent : root.levelColor))
                        : Qt.rgba(Theme.line.r, Theme.line.g, Theme.line.b, 0.55)
                    opacity: index / 24.0 <= root.fraction ? 1 : 0.65
                }
            }
        }

        Row {
            width: parent.width
            height: 20

            Text { text: "0%"; color: Theme.textFaint; font.family: Theme.mono; font.pixelSize: 7 }
            Item { width: parent.width - 44; height: 1 }
            Text { text: "100%"; color: Theme.textFaint; font.family: Theme.mono; font.pixelSize: 7 }
        }

        Item {
            width: parent.width
            height: System.powerProfileAvailable ? 50 : 0
            visible: System.powerProfileAvailable

            Column {
                anchors.fill: parent
                spacing: 5

                Text {
                    text: "POWER MODE  /  电源模式"
                    color: Theme.textFaint
                    font.family: Theme.mono
                    font.pixelSize: 7
                    font.letterSpacing: 0.7
                }

                Row {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: System.powerProfiles

                        delegate: ChamferButton {
                            required property var modelData
                            width: (parent.width - 12) / 3
                            label: modelData.label
                            accent: modelData.active
                            onClicked: System.setPowerProfile(modelData.id)
                        }
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.line }

        Row {
            width: parent.width
            height: 26

            Text {
                text: "HEALTH  " + (System.batteryHealth > 0 ? System.batteryHealth + "%" : "--")
                color: Theme.textDim
                font.family: Theme.mono
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 280; height: 1 }

            Text {
                text: "SOURCE  SYSFS / POWER_SUPPLY"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 7
                font.letterSpacing: 0.4
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            width: parent.width
            text: {
                switch (System.batteryStatus) {
                case "Charging": return "充电中"
                case "Discharging": return "放电中"
                case "Full": return "已充满"
                case "Not charging": return "未充电"
                default: return System.batteryStatus
                }
            }
            color: Theme.textFaint
            font.family: Theme.cjk
            font.pixelSize: 10
            horizontalAlignment: Text.AlignRight
        }
    }

    EmptyState {
        anchors.centerIn: parent
        icon: "bolt"
        title: "NO BATTERY DETECTED"
        detail: "系统正在使用交流电"
        visible: !System.batteryPresent
    }
}
