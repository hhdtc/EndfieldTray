import QtQuick
import "../components"
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string service: ""
    property var rootItems: []
    property var columns: []

    width: 230 * Math.max(1, columns.length)
    height: 360
    opacity: 0

    signal closeRequested()

    Behavior on opacity { NumberAnimation { duration: 130 } }

    onRootItemsChanged: {
        if (rootItems && rootItems.length > 0) {
            columns = [{ title: "SIGNAL MENU", items: rootItems, level: 0 }]
        } else {
            columns = []
        }
    }

    function openItem(columnIndex, item) {
        if (!item.enabled)
            return
        if (item.hasChildren) {
            let children = item.children || []
            if (children.length === 0 && root.service.length > 0) {
                children = TrayMenu.submenuFor(root.service, item.id)
            }
            if (children.length > 0) {
                const next = root.columns.slice(0, columnIndex + 1)
                next.push({ title: item.label, items: children, level: columnIndex + 1 })
                root.columns = next
            }
        } else {
            if (root.service.length > 0)
                TrayMenu.triggerMenu(root.service, item.id)
            root.closeRequested()
        }
    }

    EndfieldFrame {
        anchors.fill: parent
        cut: 14
        accentFrom: 0.04
        accentTo: 0.25
    }

    Item {
        anchors.fill: parent
        anchors.margins: 14

        Item {
            id: header
            width: parent.width
            height: 28

            Text {
                text: "TRAY  /  " + (root.columns.length > 0 ? root.columns[0].title : "MENU")
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.service
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 7
                anchors.left: parent.horizontalCenter
                anchors.leftMargin: 46
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 310
                elide: Text.ElideMiddle
            }

            Item {
                width: 24
                height: 24
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    color: closeMouse.containsMouse ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.12) : "transparent"
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
                    onClicked: root.closeRequested()
                }
            }
        }

        Rectangle {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.line
        }

        Row {
            anchors.top: header.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 0

            Repeater {
                model: root.columns

                delegate: Item {
                    id: columnItem
                    required property int index
                    required property var modelData

                    width: 230
                    height: parent.height

                    Column {
                        anchors.fill: parent
                        spacing: 4

                        Row {
                            width: parent.width
                            height: 20
                            spacing: 6

                            Item {
                                visible: columnItem.index > 0
                                width: 18
                                height: 18
                                IconGlyph {
                                    anchors.centerIn: parent
                                    name: "chevron-left"
                                    width: 10
                                    height: 10
                                    color: backMouse.containsMouse ? Theme.accent : Theme.textFaint
                                }
                                MouseArea {
                                    id: backMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.columns = root.columns.slice(0, columnItem.index)
                                }
                            }

                            Text {
                                text: columnItem.modelData.title
                                color: Theme.textFaint
                                font.family: Theme.mono
                                font.pixelSize: 8
                                font.letterSpacing: 0.7
                                elide: Text.ElideRight
                                width: parent.width - 50
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 24
                            clip: true
                            model: columnItem.modelData.items
                            spacing: 1
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Item {
                                id: menuRow
                                required property int index
                                required property var modelData

                                width: parent.width - 6
                                height: modelData.separator ? 8 : 30

                                Rectangle {
                                    visible: modelData.separator
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 1
                                    color: Theme.line
                                }

                                Rectangle {
                                    visible: !modelData.separator
                                    anchors.fill: parent
                                    color: menuMouse.containsMouse && modelData.enabled
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                                        : "transparent"
                                }

                                Item {
                                    visible: !modelData.separator && modelData.checkable
                                    width: 12
                                    height: 12
                                    x: 4
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        anchors.fill: parent
                                        border.width: 1
                                        border.color: modelData.checked ? Theme.accent : Theme.lineBright
                                        color: "transparent"
                                    }
                                    Rectangle {
                                        visible: modelData.checked
                                        width: 6
                                        height: 6
                                        anchors.centerIn: parent
                                        color: Theme.accent
                                    }
                                }

                                Kirigami.Icon {
                                    visible: !modelData.separator && modelData.icon.length > 0
                                    source: modelData.icon
                                    width: 14
                                    height: 14
                                    x: modelData.checkable ? 22 : 6
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    visible: !modelData.separator
                                    x: modelData.checkable ? 42 : (modelData.icon.length > 0 ? 24 : 8)
                                    width: parent.width - x - 18
                                    text: modelData.label
                                    color: !modelData.enabled ? Theme.textFaint
                                        : (menuMouse.containsMouse ? Theme.text : Theme.textDim)
                                    font.family: Theme.cjk
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                IconGlyph {
                                    visible: !modelData.separator && modelData.hasChildren
                                    anchors.right: parent.right
                                    anchors.rightMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "chevron"
                                    width: 9
                                    height: 9
                                    color: Theme.textFaint
                                }

                                MouseArea {
                                    id: menuMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !modelData.separator && modelData.enabled
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.openItem(columnItem.index, modelData)
                                }
                            }

                            EmptyState {
                                anchors.centerIn: parent
                                icon: "tray"
                                title: "NO MENU"
                                detail: "该托盘项目没有可用的菜单"
                                visible: !columnItem.modelData.items || columnItem.modelData.items.length === 0
                            }
                        }
                    }

                    Rectangle {
                        visible: columnItem.index < root.columns.length - 1
                        width: 1
                        height: parent.height
                        anchors.right: parent.right
                        color: Theme.line
                    }
                }
            }
        }
    }
}
