pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window 2.15 as QW
import QtQuick.Controls
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami
import "components"
import "panels"

QW.Window {
    id: root

    visible: true
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: "Endfield Tray"

    readonly property bool windowed: App.windowed
    readonly property var screenInfo: root.screen
    readonly property int screenW: screenInfo ? screenInfo.width : 1920
    readonly property int screenH: screenInfo ? screenInfo.height : 1080
    readonly property int barWidth: Math.min(Theme.barWidth, screenW - 48)
    readonly property int barHeight: Theme.barHeight
    readonly property int bottomGap: 10
    readonly property bool overlay: activePanel.length > 0

    property string activePanel: ""
    property real panelX: 0
    property string trayService: ""
    property var trayItems: []
    property real trayAnchorX: 0
    property string toastMessage: ""
    property bool toastSuccess: true
    property bool toastShown: false
    property string clockText: "--:--"
    property string dateText: "--- / -- ---"

    width: windowed ? 1180 : (overlay ? screenW : barWidth)
    height: windowed ? 760 : (overlay ? screenH : barHeight + bottomGap + 2)
    x: windowed ? Math.max(0, (screenW - width) / 2) : 0
    y: windowed ? 96 : 0

    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.scope: "endfield-tray"
    LayerShell.Window.activateOnShow: false
    LayerShell.Window.wantsToBeOnActiveScreen: false
    LayerShell.Window.keyboardInteractivity: overlay
        ? LayerShell.Window.KeyboardInteractivityOnDemand
        : LayerShell.Window.KeyboardInteractivityNone

    readonly property int panelBottom: height - bottomGap - barHeight - 10

    onActivePanelChanged: {
        if (activePanel.length > 0) {
            root.requestActivate()
            if (activePanel === "network")
                System.refreshNetworks()
        }
    }

    onClosing: Qt.quit()

    function updateClock() {
        const now = new Date()
        clockText = Qt.formatTime(now, "HH:mm")
        dateText = Qt.formatDate(now, "ddd").toUpperCase() + " / " + Qt.formatDate(now, "dd MMM").toUpperCase()
    }

    function closePanels() {
        activePanel = ""
        trayService = ""
        trayItems = []
        toastShown = false
    }

    function globalX(item) {
        if (!item)
            return root.screenW / 2
        // Measure relative to the bar, whose content geometry never changes,
        // then add the fixed offset of the centered bar on the final screen.
        const point = item.mapToItem(bar, item.width / 2, 0)
        return (root.screenW - root.barWidth) / 2 + point.x
    }

    function panelXFor(item, panelWidth) {
        return Math.max(10, Math.min(root.screenW - panelWidth - 10, globalX(item) - panelWidth / 2))
    }

    function togglePanel(name, anchor) {
        if (activePanel === name) {
            closePanels()
            return
        }
        const widths = {
            windows: 500,
            power: 360,
            network: 430,
            volume: 340,
            battery: 360,
            tray: 410
        }
        const width = widths[name] || 360
        // Set the overlay first: the window becomes screen-wide, so the anchor
        // must be measured in the expanded coordinate space.
        activePanel = name
        panelX = panelXFor(anchor, width)
        Qt.callLater(function() { panelX = panelXFor(anchor, width) })
    }

    function showToast(message, success) {
        toastMessage = message
        toastSuccess = success
        toastShown = true
        toastTimer.restart()
    }

    function openTrayMenu(service, anchorX) {
        if (!service)
            return
        const items = TrayMenu.menuFor(service)
        if (!items || items.length === 0) {
            TrayMenu.activate(service, Qt.RightButton)
            return
        }
        trayService = service
        trayItems = items
        trayAnchorX = anchorX
        activePanel = "trayMenu"
    }

    function trayItemClicked(service, itemIsMenu, anchorX, button) {
        if (button === Qt.RightButton || itemIsMenu) {
            openTrayMenu(service, anchorX)
        } else if (button === Qt.MiddleButton) {
            TrayMenu.activate(service, Qt.MiddleButton)
        } else {
            TrayMenu.activate(service, Qt.LeftButton)
        }
    }

    Timer {
        id: clockTimer
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.updateClock()
    }

    Timer {
        id: toastTimer
        interval: 3200
        onTriggered: root.toastShown = false
    }

    Component.onCompleted: {
        updateClock()
        System.refreshAll()
        if (App.previewPanel && App.previewPanel.length > 0) {
            const preview = App.previewPanel
            if (preview === "trayMenu") {
                Qt.callLater(function() {
                    if (TrayModel.count > 0)
                        root.openTrayMenu(TrayModel.serviceAt(0), screenW - 120)
                })
            } else {
                const anchors = {
                    windows: windowsButton,
                    power: powerButton,
                    network: networkChip,
                    volume: volumeChip,
                    battery: batteryChip,
                    tray: trayDrawer
                }
                root.togglePanel(preview, anchors[preview] || windowsButton)
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.closePanels()
    }

    Connections {
        target: System
        function onNetworkResult(ok, message) {
            root.showToast(message, ok)
        }
        function onPowerResult(ok, message) {
            root.showToast(message, ok)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#44020705"
        opacity: root.overlay ? 1 : 0
        visible: opacity > 0
        z: 1
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        z: 2
        enabled: root.overlay
        onClicked: root.closePanels()
    }

    // ---------------------------------------------------------------------
    // Compact floating strip
    // ---------------------------------------------------------------------
    Item {
        id: bar
        width: root.barWidth
        height: root.barHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - root.barHeight - root.bottomGap
        z: 20

        EndfieldFrame {
            anchors.fill: parent
            radius: root.barHeight / 2
            accentFrom: 0.035
            accentTo: 0.075
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            IconGlyph {
                name: "diamond"
                width: 23
                height: 23
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2

                Text {
                    text: "ENDFIELD"
                    color: Theme.text
                    font.family: Theme.sans
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                }

                Text {
                    text: "TRAY  /  07"
                    color: Theme.accentDim
                    font.family: Theme.mono
                    font.pixelSize: 6
                    font.letterSpacing: 0.8
                }
            }

            Rectangle {
                width: 1
                height: 22
                color: Theme.lineBright
                anchors.verticalCenter: parent.verticalCenter
            }

            BarButton {
                id: windowsButton
                anchors.verticalCenter: parent.verticalCenter
                icon: "windows"
                label: "WINDOWS"
                trailing: WindowModel.count > 0 ? String(WindowModel.count).padStart(2, "0") : "--"
                active: root.activePanel === "windows"
                onClicked: root.togglePanel("windows", windowsButton)
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: -4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.clockText
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: 21
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateText
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 6
                font.letterSpacing: 0.9
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            StatusChip {
                id: networkChip
                anchors.verticalCenter: parent.verticalCenter
                icon: System.wifiConnected ? "wifi" : (System.wifiEnabled ? "wifi" : "wifi-off")
                text: System.wifiConnected
                    ? (System.wifiSsid.length > 7 ? System.wifiSsid.substring(0, 7) : System.wifiSsid)
                    : (System.wifiEnabled ? "OFF" : "RADIO")
                active: root.activePanel === "network"
                warning: System.wifiEnabled && !System.wifiConnected
                onClicked: root.togglePanel("network", networkChip)
            }

            StatusChip {
                id: volumeChip
                anchors.verticalCenter: parent.verticalCenter
                icon: System.muted ? "volume-mute" : "volume"
                text: System.volume + "%"
                active: root.activePanel === "volume"
                warning: System.muted
                onClicked: root.togglePanel("volume", volumeChip)
                onWheeled: wheel => System.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5)
            }

            StatusChip {
                id: batteryChip
                visible: System.batteryPresent
                anchors.verticalCenter: parent.verticalCenter
                icon: System.charging ? "battery-charging" : "battery"
                text: System.batteryPercent + "%"
                active: root.activePanel === "battery"
                warning: System.batteryPercent <= 18 && !System.charging
                level: System.batteryPercent / 100.0
                charging: System.charging
                onClicked: root.togglePanel("battery", batteryChip)
            }

            Rectangle {
                width: 1
                height: 20
                color: Theme.line
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: 0
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: TrayModel

                    delegate: Item {
                        id: trayIcon
                        required property int index
                        required property var model

                        visible: index < 4
                        width: visible ? 22 : 0
                        height: 34
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 8
                            color: trayMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) : "transparent"
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            visible: model.iconName.length > 0
                            width: 16
                            height: 16
                            source: model.iconName
                        }

                        IconGlyph {
                            anchors.centerIn: parent
                            visible: model.iconName.length === 0
                            name: "diamond"
                            width: 13
                            height: 13
                            color: Theme.textDim
                        }

                        Rectangle {
                            visible: model.attention
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.warning
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.top: parent.top
                            anchors.topMargin: 4
                        }

                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                root.trayItemClicked(model.service, model.itemIsMenu, root.globalX(trayIcon), mouse.button)
                            }
                        }
                    }
                }
            }

            Item {
                id: trayDrawer
                width: 24
                height: 34
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 8
                    color: drawerMouse.containsMouse || root.activePanel === "tray"
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.09) : "transparent"
                }

                IconGlyph {
                    anchors.centerIn: parent
                    name: "tray"
                    width: 14
                    height: 14
                    color: drawerMouse.containsMouse || root.activePanel === "tray" ? Theme.accent : Theme.textDim
                }

                MouseArea {
                    id: drawerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePanel("tray", trayDrawer)
                }
            }

            Item {
                id: powerButton
                width: 34
                height: 34
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 17
                    color: powerMouse.containsMouse || root.activePanel === "power"
                        ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                    border.width: 1
                    border.color: Theme.accent
                }

                IconGlyph {
                    anchors.centerIn: parent
                    name: "power"
                    width: 16
                    height: 16
                    color: powerMouse.containsMouse || root.activePanel === "power" ? Theme.bg : Theme.accent
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePanel("power", powerButton)
                }
            }
        }
    }

    // ---------------------------------------------------------------------
    // Panels
    // ---------------------------------------------------------------------
    WindowsPanel {
        z: 30
        isActive: root.activePanel === "windows"
        x: root.panelX
        y: root.panelBottom - height
        onCloseRequested: root.closePanels()
    }

    PowerPanel {
        z: 30
        isActive: root.activePanel === "power"
        x: root.panelX
        y: root.panelBottom - height
        onCloseRequested: root.closePanels()
        onPowerRequested: (action, label) => {
            System.powerAction(action)
            root.closePanels()
        }
    }

    NetworkPanel {
        z: 30
        isActive: root.activePanel === "network"
        x: root.panelX
        y: root.panelBottom - height
        onCloseRequested: root.closePanels()
    }

    VolumePanel {
        z: 30
        isActive: root.activePanel === "volume"
        x: root.panelX
        y: root.panelBottom - height
        onCloseRequested: root.closePanels()
    }

    BatteryPanel {
        z: 30
        isActive: root.activePanel === "battery"
        x: root.panelX
        y: root.panelBottom - height
        onCloseRequested: root.closePanels()
    }

    TrayPanel {
        id: trayPanel
        isActive: root.activePanel === "tray"
        x: root.panelX
        y: root.panelBottom - height
        trayModel: TrayModel
        onCloseRequested: root.closePanels()
        onItemActivated: (service, button) => {
            TrayMenu.activate(service, button)
            root.closePanels()
        }
        onMenuRequested: (service, xInPanel) => {
            root.openTrayMenu(service, trayPanel.x + xInPanel)
        }
    }

    TrayMenuPanel {
        z: 30
        id: trayMenuPanel
        service: root.trayService
        rootItems: root.trayItems
        visible: root.activePanel === "trayMenu"
        opacity: visible ? 1 : 0
        x: Math.max(10, Math.min(root.width - width - 10, root.trayAnchorX - width + 30))
        y: root.panelBottom - height
        onCloseRequested: root.closePanels()
    }

    Toast {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - root.barHeight - root.bottomGap - 38
        z: 50
        message: root.toastMessage
        success: root.toastSuccess
        shown: root.toastShown && root.overlay
    }

}
