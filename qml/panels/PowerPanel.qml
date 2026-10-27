import QtQuick
import "../components"

BasePanel {
    id: root

    panelWidth: 360
    panelHeight: 415
    code: "01"
    title: "电源"
    detail: "POWER / SESSION"
    opacity: isActive ? 1 : 0
    visible: isActive

    property bool isActive: false
    property string pendingAction: ""
    property string pendingLabel: ""

    signal powerRequested(string action, string label)

    onIsActiveChanged: {
        if (!isActive) {
            pendingAction = ""
            pendingLabel = ""
        }
    }

    Column {
        anchors.fill: parent
        spacing: 6

        Row {
            width: parent.width
            height: 34

            Column {
                spacing: 1
                Text {
                    text: "OPERATOR  /  LOCAL SESSION"
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.letterSpacing: 0.8
                }
                Text {
                    text: "ACTIVE SESSION  ·  LOCAL CONSOLE"
                    color: Theme.textFaint
                    font.family: Theme.mono
                    font.pixelSize: 8
                    font.letterSpacing: 0.8
                }
            }

            Item { width: parent.width - 250; height: 1 }

            Rectangle {
                width: 7
                height: 7
                rotation: 45
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "READY"
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: 8
                font.letterSpacing: 0.8
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Repeater {
            model: [
                { action: "sleep", icon: "sleep", title: "睡眠", code: "SLEEP", sub: "SUSPEND TO RAM", hint: "S" },
                { action: "reboot", icon: "reboot", title: "重启", code: "RESTART", sub: "REBOOT SYSTEM", hint: "R" },
                { action: "shutdown", icon: "shutdown", title: "关机", code: "SHUTDOWN", sub: "POWER OFF", hint: "P" },
                { action: "logout", icon: "logout", title: "注销", code: "LOGOUT", sub: "END SESSION", hint: "L" }
            ]

            Item {
                required property int index
                required property var modelData

                width: parent.width
                height: 48

                Rectangle {
                    anchors.fill: parent
                    color: powerMouse.containsMouse
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.065)
                        : "transparent"
                    border.width: 1
                    border.color: powerMouse.containsMouse ? Theme.line : "transparent"
                }

                Rectangle {
                    width: 2
                    height: parent.height - 18
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: modelData.action === "shutdown" ? Theme.danger : Theme.accent
                    opacity: powerMouse.containsMouse ? 1 : 0.3
                }

                IconGlyph {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData.icon
                    width: 18
                    height: 18
                    color: modelData.action === "shutdown" && powerMouse.containsMouse ? Theme.danger : Theme.textDim
                }

                Column {
                    x: 52
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: modelData.code + "  /  " + modelData.title
                        color: modelData.action === "shutdown" && powerMouse.containsMouse ? Theme.danger : Theme.text
                        font.family: Theme.sans
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }

                    Text {
                        text: modelData.sub
                        color: Theme.textFaint
                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.letterSpacing: 0.8
                    }
                }

                IconGlyph {
                    anchors.right: parent.right
                    anchors.rightMargin: 38
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevron"
                    width: 10
                    height: 10
                    color: Theme.textFaint
                    visible: powerMouse.containsMouse
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.pendingAction = modelData.action
                        root.pendingLabel = modelData.title
                    }
                }
            }
        }

        Item { width: 1; height: 4 }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.line
        }

        Item {
            width: parent.width
            height: 60

            Column {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 8
                spacing: 3

                Text {
                    text: root.pendingAction.length > 0 ? "CONFIRM ACTION" : "SESSION CONTROL"
                    color: root.pendingAction.length > 0 ? Theme.accent : Theme.textFaint
                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Text {
                    text: root.pendingAction.length > 0
                        ? ("确认执行 " + root.pendingLabel + " ？")
                        : "选择操作后需要二次确认"
                    color: root.pendingAction.length > 0 ? Theme.text : Theme.textFaint
                    font.family: Theme.cjk
                    font.pixelSize: 12
                }
            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 8
                visible: root.pendingAction.length > 0

                ChamferButton {
                    label: "取消"
                    onClicked: {
                        root.pendingAction = ""
                        root.pendingLabel = ""
                    }
                }

                ChamferButton {
                    label: "确认"
                    accent: true
                    icon: "check"
                    onClicked: {
                        root.powerRequested(root.pendingAction, root.pendingLabel)
                        root.pendingAction = ""
                        root.pendingLabel = ""
                    }
                }
            }
        }
    }
}
