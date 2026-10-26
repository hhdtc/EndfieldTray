import QtQuick
import QtQuick.Controls
import "../components"

BasePanel {
    id: root

    panelWidth: 430
    panelHeight: 440
    code: "03"
    title: "网络"
    detail: "NETWORK / UPLINK"
    opacity: isActive ? 1 : 0
    visible: isActive

    property bool isActive: false
    property string selectedSsid: ""
    property string selectedSecurity: ""

    onIsActiveChanged: {
        if (!isActive) {
            selectedSsid = ""
            selectedSecurity = ""
        }
    }

    function choose(network) {
        if (network.active)
            return
        if (network.secure) {
            root.selectedSsid = network.ssid
            root.selectedSecurity = network.security
            passwordField.text = ""
            passwordField.forceActiveFocus()
        } else {
            System.connectWifi(network.ssid, "")
        }
    }

    Column {
        anchors.fill: parent
        spacing: 7

        Item {
            width: parent.width
            height: 54

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.55)
                border.width: 1
                border.color: Theme.line
            }

            StatusChip {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                icon: System.wifiConnected ? "wifi" : (System.wifiEnabled ? "wifi" : "wifi-off")
                text: System.wifiConnected ? System.wifiSsid : (System.wifiEnabled ? "未连接" : "Wi-Fi 已关闭")
                subtext: System.wifiConnected ? (System.wifiSignal + "%  /  " + (System.wifiSignal > 70 ? "EXCELLENT" : System.wifiSignal > 40 ? "STABLE" : "WEAK")) : "NO ACTIVE UPLINK"
                horizontalPadding: 8
            }

            SignalBars {
                anchors.right: disconnectButton.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                strength: System.wifiSignal
                color: Theme.textDim
                activeColor: Theme.accent
                visible: System.wifiConnected
            }

            ChamferButton {
                id: disconnectButton
                anchors.right: toggleButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                label: "断开"
                visible: System.wifiConnected
                onClicked: System.disconnectWifi()
            }

            ChamferButton {
                id: toggleButton
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                label: System.wifiEnabled ? "RADIO ON" : "RADIO OFF"
                accent: System.wifiEnabled
                onClicked: System.setWifiEnabled(!System.wifiEnabled)
            }
        }

        Row {
            width: parent.width
            height: 22

            Text {
                text: "AVAILABLE ACCESS POINTS"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 8
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 210; height: 1 }

            IconGlyph {
                id: refreshIcon
                width: 13
                height: 13
                name: "refresh"
                color: refreshMouse.containsMouse ? Theme.accent : Theme.textFaint
                anchors.verticalCenter: parent.verticalCenter

                RotationAnimator on rotation {
                    running: System.scanning
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: System.refreshNetworks()
                }
            }

            Item { width: 5; height: 1 }

            Text {
                text: System.scanning ? "SCANNING" : "RESCAN"
                color: System.scanning ? Theme.accent : (refreshMouse.containsMouse ? Theme.accent : Theme.textFaint)
                font.family: Theme.mono
                font.pixelSize: 7
                font.letterSpacing: 0.7
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        ListView {
            id: networkList
            width: parent.width
            height: root.selectedSsid.length > 0 ? 226 : 318
            clip: true
            model: System.wifiNetworks
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: netRow
                required property int index
                required property var modelData

                width: networkList.width
                height: 46

                Rectangle {
                    anchors.fill: parent
                    color: modelData.active
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                        : (netMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.045) : "transparent")
                    border.width: netMouse.containsMouse || modelData.active ? 1 : 0
                    border.color: modelData.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : Theme.line
                }

                SignalBars {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    strength: modelData.signal
                    color: Theme.textFaint
                    activeColor: modelData.active ? Theme.accent : Theme.text
                }

                Column {
                    x: 48
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 128
                    spacing: 1

                    Row {
                        spacing: 6

                        Text {
                            text: modelData.ssid
                            color: modelData.active ? Theme.accent : Theme.text
                            font.family: Theme.cjk
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.parent.width - 50)
                        }

                        IconGlyph {
                            visible: modelData.secure
                            name: "lock"
                            width: 10
                            height: 10
                            color: Theme.textFaint
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        text: modelData.security + "  /  " + modelData.signal + "%"
                        color: Theme.textFaint
                        font.family: Theme.mono
                        font.pixelSize: 8
                        font.letterSpacing: 0.4
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.active ? "CONNECTED" : ""
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 7
                    font.letterSpacing: 0.6
                }

                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.choose(modelData)
                }
            }

            EmptyState {
                anchors.centerIn: parent
                icon: System.wifiEnabled ? "search" : "wifi-off"
                title: System.wifiEnabled ? "NO SIGNAL FOUND" : "RADIO OFFLINE"
                detail: System.wifiEnabled ? "点击右上角重新扫描" : "开启 Wi-Fi 以扫描网络"
                visible: System.wifiNetworks.length === 0
            }
        }

        Item {
            width: parent.width
            height: root.selectedSsid.length > 0 ? 82 : 0
            visible: height > 0
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.55)
                border.width: 1
                border.color: Theme.accentDim
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Row {
                    spacing: 6
                    Text {
                        text: "AUTH / " + root.selectedSsid
                        color: Theme.accent
                        font.family: Theme.mono
                        font.pixelSize: 8
                        font.letterSpacing: 0.6
                    }
                    Text {
                        text: root.selectedSecurity
                        color: Theme.textFaint
                        font.family: Theme.mono
                        font.pixelSize: 8
                    }
                }

                Row {
                    spacing: 8
                    width: parent.width

                    TextField {
                        id: passwordField
                        width: parent.width - connectButton.width - 8
                        height: 32
                        placeholderText: "Wi-Fi 密码"
                        placeholderTextColor: Theme.textFaint
                        echoMode: TextInput.Password
                        color: Theme.text
                        selectionColor: Theme.accentDim
                        selectedTextColor: Theme.bg
                        font.family: Theme.mono
                        font.pixelSize: 11
                        leftPadding: 10
                        rightPadding: 10
                        background: Rectangle {
                            color: Theme.bg
                            border.width: 1
                            border.color: passwordField.activeFocus ? Theme.accent : Theme.lineBright
                        }
                        onAccepted: {
                            if (text.length > 0) {
                                System.connectWifi(root.selectedSsid, text)
                                root.selectedSsid = ""
                            }
                        }
                    }

                    ChamferButton {
                        id: connectButton
                        label: System.connecting ? "连接中" : "连接"
                        accent: true
                        interactive: passwordField.text.length > 0 && !System.connecting
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            System.connectWifi(root.selectedSsid, passwordField.text)
                            root.selectedSsid = ""
                        }
                    }

                    ChamferButton {
                        label: "取消"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.selectedSsid = ""
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 18

            Text {
                text: "NETWORKMANAGER / " + (System.wifiConnected ? "ONLINE" : "STANDBY")
                color: System.wifiConnected ? Theme.accentDim : Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 7
                font.letterSpacing: 0.7
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 220; height: 1 }

            Text {
                text: "WPA2 / WPA3 SUPPORTED"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 7
                font.letterSpacing: 0.5
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
