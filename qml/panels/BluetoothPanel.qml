import QtQuick
import "../components"

BasePanel {
    id: root

    panelWidth: 390
    panelHeight: 430
    code: "07"
    title: "蓝牙"
    detail: "WIRELESS / BLUETOOTH"
    opacity: isActive ? 1 : 0
    visible: isActive

    property bool isActive: false

    onIsActiveChanged: {
        if (isActive)
            System.refreshBluetooth()
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width: parent.width
            height: 54

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.14)
            }

            IconGlyph {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                name: "bluetooth"
                color: System.bluetoothEnabled ? Theme.accent : Theme.textFaint
            }

            Column {
                x: 39
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "BLUETOOTH  /  ADAPTER"
                    color: System.bluetoothEnabled ? Theme.accent : Theme.textDim
                    font.family: Theme.mono
                    font.pixelSize: 8
                    font.letterSpacing: 0.8
                }

                Text {
                    text: System.bluetoothEnabled
                        ? (System.bluetoothConnected ? "DEVICE CONNECTED" : "POWERED / NO DEVICE")
                        : "ADAPTER OFF"
                    color: Theme.textFaint
                    font.family: Theme.mono
                    font.pixelSize: 7
                    font.letterSpacing: 0.4
                }
            }

            ChamferButton {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                label: System.bluetoothEnabled ? "OFF" : "ON"
                accent: !System.bluetoothEnabled
                onClicked: System.setBluetoothEnabled(!System.bluetoothEnabled)
            }
        }

        Row {
            width: parent.width
            height: 20

            Text {
                text: "KNOWN DEVICES"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 8
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 280; height: 1 }

            Text {
                text: System.bluetoothDevices.length + " 个设备"
                color: Theme.accent
                font.family: Theme.cjk
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }

            ChamferButton {
                width: 74
                anchors.verticalCenter: parent.verticalCenter
                label: System.bluetoothDiscovering ? "SCANNING" : "SCAN"
                interactive: !System.bluetoothDiscovering
                onClicked: System.scanBluetooth()
            }
        }

        ListView {
            id: deviceList
            width: parent.width
            height: 236
            clip: true
            model: System.bluetoothDevices
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            visible: System.bluetoothDevices.length > 0

            delegate: Item {
                id: row
                required property int index
                required property var modelData

                width: deviceList.width
                height: 46

                Rectangle {
                    anchors.fill: parent
                    color: modelData.connected
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                        : (rowMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.045) : "transparent")
                }

                IconGlyph {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    name: "bluetooth"
                    color: modelData.connected ? Theme.accent : Theme.textDim
                }

                Column {
                    x: 38
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 150
                    spacing: 2

                    Text {
                        width: parent.width
                        text: modelData.name
                        color: modelData.connected ? Theme.accent : Theme.text
                        font.family: Theme.cjk
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.address
                        color: Theme.textFaint
                        font.family: Theme.mono
                        font.pixelSize: 7
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.connected ? "CONNECTED" : "CONNECT"
                    color: modelData.connected ? Theme.accent : Theme.textFaint
                    font.family: Theme.mono
                    font.pixelSize: 7
                    font.letterSpacing: 0.6
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.connected)
                            System.disconnectBluetooth(modelData.address)
                        else
                            System.connectBluetooth(modelData.address)
                    }
                }
            }
        }

        EmptyState {
            width: parent.width
            height: 236
            visible: System.bluetoothDevices.length === 0
            icon: "bluetooth"
            title: System.bluetoothEnabled ? "NO KNOWN DEVICES" : "ADAPTER OFFLINE"
            detail: System.bluetoothEnabled ? "点击 SCAN 搜索附近设备" : "开启蓝牙以搜索设备"
        }

        Text {
            text: "BLUEZ  /  BLUETOOTHCTL"
            color: Theme.textFaint
            font.family: Theme.mono
            font.pixelSize: 7
            font.letterSpacing: 0.8
            anchors.right: parent.right
        }
    }
}
