pragma ComponentBehavior: Bound

import QtQuick
import "../components"
import org.kde.kirigami as Kirigami

BasePanel {
    id: root

    panelWidth: 410
    panelHeight: 270
    code: "06"
    title: "托盘"
    detail: "SYSTEM TRAY / SIGNALS"
    opacity: isActive ? 1 : 0
    visible: isActive

    property bool isActive: false
    property var trayModel

    signal itemActivated(string service, int button)
    signal menuRequested(string service, real xInPanel)


    Column {
        anchors.fill: parent
        spacing: 7

        Row {
            width: parent.width
            height: 20

            Text {
                text: grid.count + " 个常驻信号"
                color: Theme.textFaint
                font.family: Theme.cjk
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 270; height: 1 }

            Text {
                text: "CLICK ACTIVATE  /  RIGHT CLICK MENU"
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 7
                font.letterSpacing: 0.5
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        GridView {
            id: grid
            width: parent.width
            height: parent.height - 28
            clip: true
            cellWidth: width / 4
            cellHeight: 72
            model: root.trayModel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: cell
                required property int index
                required property var model

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    color: cellMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06) : "transparent"
                    border.width: cellMouse.containsMouse ? 1 : 0
                    border.color: Theme.line
                }

                Kirigami.Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: model.iconName.length > 0
                    y: 11
                    width: 22
                    height: 22
                    source: model.iconName
                }

                IconGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: model.iconName.length === 0
                    y: 11
                    width: 22
                    height: 22
                    name: "diamond"
                    color: Theme.textDim
                }

                Rectangle {
                    visible: model.attention
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Theme.warning
                    x: parent.width / 2 + 12
                    y: 12
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 42
                    width: parent.width - 12
                    text: model.title || "APPLICATION"
                    color: cellMouse.containsMouse ? Theme.text : Theme.textDim
                    font.family: Theme.cjk
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton || model.itemIsMenu) {
                            root.menuRequested(model.service, cell.x + cell.width / 2)
                        } else {
                            root.itemActivated(model.service, Qt.LeftButton)
                        }
                    }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                icon: "tray"
                title: "TRAY EMPTY"
                detail: "当前没有注册的托盘项目"
                visible: root.trayModel && grid.count === 0
            }
        }
    }
}
