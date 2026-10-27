import QtQuick
import "../components"
import org.kde.kirigami as Kirigami

BasePanel {
    id: root

    panelWidth: 500
    panelHeight: 380
    code: "02"
    title: "窗口"
    detail: "OPEN WINDOWS / TASKS"
    opacity: isActive ? 1 : 0
    visible: isActive

    property bool isActive: false


    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            height: 20

            Text {
                text: "SIGNAL  /  ACTIVE WINDOWS"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 8
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 270; height: 1 }

            Text {
                text: WindowModel.count + " 个窗口"
                color: Theme.accent
                font.family: Theme.cjk
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - 58
            clip: true
            model: WindowModel
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row
                required property int index
                required property string title
                required property string appName
                required property var icon
                required property bool active
                required property bool minimized
                required property bool closable

                width: list.width
                height: 46

                Rectangle {
                    anchors.fill: parent
                    color: row.active
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                        : (rowMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.045) : "transparent")
                    border.width: row.active ? 1 : 0
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
                }

                Rectangle {
                    width: 2
                    height: parent.height - 12
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent
                    opacity: row.active ? 1 : 0
                }

                Kirigami.Icon {
                    id: appIcon
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    source: row.icon ? row.icon : "application-x-executable"
                    opacity: row.minimized ? 0.5 : 1
                }

                Column {
                    x: 47
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 100
                    spacing: 1

                    Text {
                        width: parent.width
                        text: row.title
                        color: row.active ? Theme.text : (row.minimized ? Theme.textFaint : Theme.textDim)
                        font.family: Theme.cjk
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: (row.appName || "APPLICATION") + (row.minimized ? "  /  MINIMIZED" : "")
                        color: Theme.textFaint
                        font.family: Theme.mono
                        font.pixelSize: 8
                        elide: Text.ElideRight
                        font.letterSpacing: 0.5
                    }
                }

                Text {
                    anchors.right: closeButton.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.active ? "FOCUS" : ""
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 7
                    font.letterSpacing: 0.7
                }

                Item {
                    id: closeButton
                    width: 22
                    height: 22
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.closable && rowMouse.containsMouse

                    Rectangle {
                        anchors.fill: parent
                        color: closeMouse.containsMouse ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.14) : "transparent"
                        border.width: closeMouse.containsMouse ? 1 : 0
                        border.color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.4)
                    }

                    IconGlyph {
                        anchors.centerIn: parent
                        name: "close"
                        width: 12
                        height: 12
                        color: closeMouse.containsMouse ? Theme.danger : Theme.textFaint
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WindowModel.closeWindow(row.index)
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    anchors.rightMargin: 38
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            WindowModel.toggleMinimize(row.index)
                        } else {
                            WindowModel.activate(row.index)
                            root.closeRequested()
                        }
                    }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                icon: "windows"
                title: "NO ACTIVE SIGNALS"
                detail: "当前没有打开的窗口"
                visible: WindowModel.count === 0
            }
        }

        Row {
            width: parent.width
            height: 20

            Text {
                text: "CLICK 切换  /  MIDDLE 最小化"
                color: Theme.textFaint
                font.family: Theme.cjk
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 200; height: 1 }

            Text {
                text: "WINDOW_MANAGER / KWIN"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 7
                font.letterSpacing: 0.6
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
