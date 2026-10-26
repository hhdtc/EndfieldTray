pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Window 2.15 as QW
import QtQuick.Controls
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami
import "components"
import "panels"

QW.Window {
    id: root

    // main.cpp shows the window after setting the LayerShell scope.
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: "Endfield Tray"

    readonly property bool windowed: App.windowed
    readonly property var screenInfo: root.screen
    readonly property int screenW: screenInfo ? screenInfo.width : 1920
    readonly property int screenH: screenInfo ? screenInfo.height : 1080
    readonly property int expandedWidth: Math.min(Theme.barWidth, screenW - 48)
    readonly property int collapsedWidth: 108
    readonly property int barHeight: Theme.barHeight
    readonly property int bottomGap: 10
    readonly property bool overlay: activePanel.length > 0

    property bool barExpanded: false
    property string activePanel: ""
    property real panelX: 0
    property rect panelInputRect: Qt.rect(0, 0, 0, 0)
    property bool keyboardRequested: false

    property string trayService: ""
    property var trayItems: []
    property real trayAnchorX: 0

    property bool groupPopupVisible: false
    property bool groupPopupHovered: false
    property string previewPanelName: ""
    property var groupWindows: []
    property string groupAppName: ""
    property int groupPopupGroup: -1
    property real groupPopupX: 8
    readonly property int groupPopupWidth: 252
    readonly property int groupPopupHeight: 42 + Math.min(6, Math.max(1, groupWindows.length)) * 28

    property string toastMessage: ""
    property bool toastSuccess: true
    property bool toastShown: false
    property string clockText: "--:--"
    property string dateText: "--- / -- ---"

    readonly property int barWidth: barExpanded ? expandedWidth : collapsedWidth
    readonly property bool hudHidden: WindowModel.fullScreenActive

    onHudHiddenChanged: {
        if (hudHidden) {
            hideGroup()
            closePanels()
            barExpanded = false
            collapseTimer.stop()
            System.setUiActive(false)
            TrayModel.setActive(false)
            RecentApps.setActive(false)
            updateInputRegion()
        } else {
            updateInputRegion()
        }
    }

    // The layer surface is always screen-sized; input is restricted to the
    // visible bar/popup/panel through InputRegion, so transparent pixels never
    // swallow clicks.
    width: screenW
    height: screenH
    x: 0
    y: 0

    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.scope: "dock"
    LayerShell.Window.activateOnShow: false
    LayerShell.Window.wantsToBeOnActiveScreen: false
    LayerShell.Window.keyboardInteractivity: root.keyboardRequested
        ? LayerShell.Window.KeyboardInteractivityOnDemand
        : LayerShell.Window.KeyboardInteractivityNone

    readonly property int panelBottom: height - bottomGap - barHeight - 10

    onActivePanelChanged: {
        if (activePanel.length > 0) {
            panelCloseTimer.stop()
            expandBar()
            hideGroup()
            if (activePanel === "network")
                System.refreshNetworks()
        } else if (!barHover.hovered) {
            scheduleCollapse()
        }
        if (activePanel.length === 0) {
            panelInputRect = Qt.rect(0, 0, 0, 0)
        } else {
            updatePanelInputRect(activePanel)
        }
        if (activePanel !== "network")
            keyboardRequested = false
        updateInputRegion()
        Qt.callLater(updateInputRegion)
    }

    onPanelInputRectChanged: updateInputRegion()

    onClosing: Qt.quit()

    function updateClock() {
        const now = new Date()
        clockText = Qt.formatTime(now, "HH:mm")
        dateText = Qt.formatDate(now, "ddd").toUpperCase() + " / " + Qt.formatDate(now, "dd MMM").toUpperCase()
    }

    function expandBar() {
        collapseTimer.stop()
        barExpanded = true
    }

    function scheduleCollapse() {
        if (!overlay && !groupPopupVisible)
            collapseTimer.restart()
    }

    function closePanels() {
        panelCloseTimer.stop()
        activePanel = ""
        trayService = ""
        trayItems = []
        toastShown = false
        scheduleCollapse()
    }

    function hideGroup() {
        if (!groupPopupVisible)
            return
        groupPopupVisible = false
        groupPopupHovered = false
        groupHideTimer.stop()
        groupWindows = []
        groupPopupGroup = -1
        updateInputRegion()
        scheduleCollapse()
    }

    function scheduleHideGroup() {
        if (groupPopupVisible)
            groupHideTimer.restart()
    }

    function showGroup(groupIndex, windows, appName, item) {
        if (!windows || windows.length <= 1)
            return
        groupPopupGroup = groupIndex
        groupWindows = windows
        groupAppName = appName
        const point = item.mapToItem(bar, 0, 0)
        groupPopupX = Math.max(6, Math.min(bar.width - groupPopupWidth - 6,
                                           point.x + item.width / 2 - groupPopupWidth / 2))
        groupPopupVisible = true
        groupPopupHovered = false
        groupHideTimer.stop()
        expandBar()
        updateInputRegion()
    }

    function globalX(item) {
        if (!item)
            return root.screenW / 2
        // Measure within the bar, then apply the fixed centered-bar offset. This
        // is stable even while the bar expands/collapses.
        const point = item.mapToItem(bar, item.width / 2, 0)
        return (root.screenW - root.expandedWidth) / 2 + point.x
    }

    function panelXFor(item, panelWidth) {
        return Math.max(10, Math.min(root.screenW - panelWidth - 10, globalX(item) - panelWidth / 2))
    }

    function togglePanel(name, anchor) {
        if (activePanel === name) {
            closePanels()
            return
        }
        hideGroup()
        const widths = {
            windows: 500,
            power: 360,
            network: 430,
            volume: 360,
            battery: 390,
            bluetooth: 390,
            tray: 410
        }
        const width = widths[name] || 360
        expandBar()
        activePanel = name
        panelX = panelXFor(anchor, width)
        updatePanelInputRect(name)
        updateInputRegion()
        Qt.callLater(updateInputRegion)
        Qt.callLater(function() {
            panelX = panelXFor(anchor, width)
            updatePanelInputRect(name)
        })
    }

    function updatePanelInputRect(name) {
        const sizes = {
            windows: [500, 380],
            power: [360, 415],
            network: [430, 470],
            volume: [360, 440],
            battery: [390, 410],
            bluetooth: [390, 430],
            tray: [410, 270],
            trayMenu: [230, 360]
        }
        const size = sizes[name]
        if (!size) {
            panelInputRect = Qt.rect(0, 0, 0, 0)
            return
        }
        const scale = 0.9
        const w = size[0] * scale
        const h = size[1] * scale
        const baseX = name === "trayMenu" ? trayMenuPanel.x : panelX
        const x = baseX + (size[0] - w) / 2
        const y = panelBottom - h
        panelInputRect = Qt.rect(Math.round(x), Math.round(y), Math.ceil(w), Math.ceil(h))
    }

    function updateInputRegion() {
        if (hudHidden) {
            InputRegion.apply(Qt.rect(0, 0, 0, 0), Qt.rect(0, 0, 0, 0), Qt.rect(0, 0, 0, 0), false)
            return
        }
        const finalWidth = barExpanded ? expandedWidth : collapsedWidth
        const barX = (screenW - finalWidth) / 2
        const barY = height - barHeight - bottomGap
        const barRect = Qt.rect(barX, barY, finalWidth, barHeight)
        const popupRect = groupPopupVisible
            ? Qt.rect(barX + groupPopupX, barY - groupPopupHeight - 8,
                      groupPopupWidth, groupPopupHeight + 8)
            : Qt.rect(0, 0, 0, 0)
        // Only the bar, the group flyout and the currently visible panel are
        // interactive. The rest of the screen stays transparent to input, so
        // the active window keeps focus and its scroll wheel keeps working.
        // While the pointer is on the bar, use a full region briefly so a
        // click that opens a panel can never fall through in the same grab.
        InputRegion.apply(barRect, popupRect, panelInputRect, barHover.hovered)
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
        expandBar()
        activePanel = "trayMenu"
        Qt.callLater(function() {
            updatePanelInputRect("trayMenu")
            updateInputRegion()
        })
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

    onBarExpandedChanged: {
        System.setUiActive(root.barExpanded)
        TrayModel.setActive(root.barExpanded)
        RecentApps.setActive(root.barExpanded)
        updateInputRegion()
        Qt.callLater(updateInputRegion)
    }
    onGroupPopupVisibleChanged: {
        updateInputRegion()
        Qt.callLater(updateInputRegion)
    }
    onWidthChanged: updateInputRegion()
    onHeightChanged: updateInputRegion()

    Timer {
        id: inputRegionRefreshTimer
        interval: 250
        running: true
        onTriggered: root.updateInputRegion()
    }

    Timer {
        id: previewPanelTimer
        interval: 500
        onTriggered: {
            const anchors = {
                windows: windowsButton,
                power: powerButton,
                network: networkChip,
                volume: volumeChip,
                battery: batteryChip,
                bluetooth: bluetoothChip,
                tray: trayDrawer
            }
            root.togglePanel(root.previewPanelName, anchors[root.previewPanelName] || windowsButton)
        }
    }

    Timer {
        id: previewRecentTimer
        interval: 700
        repeat: true
        onTriggered: {
            if (RecentApps.count > 0) {
                const group = RecentApps.groupAt(0)
                root.groupPopupX = 130
                root.groupWindows = group.windows
                root.groupAppName = group.appName
                root.groupPopupVisible = true
                root.updateInputRegion()
                stop()
            }
        }
    }

    Timer {
        id: clockTimer
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.updateClock()
    }

    Timer {
        id: panelCloseTimer
        interval: 300
        onTriggered: {
            if (activePanel.length > 0 && !hudHover.hovered) {
                closePanels()
                barExpanded = false
                updateInputRegion()
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 700
        onTriggered: {
            if (!barHover.hovered && !root.overlay && !root.groupPopupVisible) {
                root.barExpanded = false
                root.hideGroup()
            }
        }
    }

    Timer {
        id: groupHideTimer
        interval: 480
        onTriggered: {
            if (!root.groupPopupHovered)
                root.hideGroup()
        }
    }

    Timer {
        id: toastTimer
        interval: 3200
        onTriggered: root.toastShown = false
    }

    Component.onCompleted: {
        updateClock()
        System.setUiActive(root.barExpanded)
        TrayModel.setActive(root.barExpanded)
        RecentApps.setActive(root.barExpanded)
        updateInputRegion()
        if (App.previewPanel && App.previewPanel.length > 0) {
            const preview = App.previewPanel
            if (preview === "trayMenu") {
                Qt.callLater(function() {
                    if (TrayModel.count > 0)
                        root.openTrayMenu(TrayModel.serviceAt(0), screenW - 120)
                })
            } else if (preview === "recent") {
                root.barExpanded = true
                previewRecentTimer.start()
            } else {
                root.previewPanelName = preview
                previewPanelTimer.start()
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
        function onNetworkResult(ok, message) { root.showToast(message, ok) }
        function onBluetoothResult(ok, message) { root.showToast(message, ok) }
        function onPowerResult(ok, message) { root.showToast(message, ok) }
        function onPowerProfileResult(ok, message) { root.showToast(message, ok) }
        function onAudioResult(ok, message) { root.showToast(message, ok) }
    }


    HoverHandler {
        id: hudHover
        onHoveredChanged: {
            if (hovered) {
                panelCloseTimer.stop()
            } else if (activePanel.length > 0 && (!App.previewPanel || App.previewPanel.length === 0)) {
                panelCloseTimer.restart()
            }
        }
    }

    // ---------------------------------------------------------------------
    // Collapsed / expanded floating strip
    // ---------------------------------------------------------------------
    Item {
        id: bar
        visible: !root.hudHidden
        width: root.barWidth
        height: root.barHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - root.barHeight - root.bottomGap
        z: 20
        clip: true

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            id: barHover
            onHoveredChanged: {
                if (hovered) {
                    root.expandBar()
                } else if (!root.groupPopupVisible) {
                    root.scheduleCollapse()
                }
                root.updateInputRegion()
                Qt.callLater(root.updateInputRegion)
            }
        }

        // Click fallback in case the compositor is slow to deliver the first
        // hover after the input region changes.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onEntered: {
                root.expandBar()
                root.updateInputRegion()
                Qt.callLater(root.updateInputRegion)
            }
            onClicked: root.expandBar()
        }

        EndfieldFrame {
            anchors.fill: parent
            radius: root.barHeight / 2
            accentFrom: 0.04
            accentTo: 0.10
            decorations: root.barExpanded
            shadow: false
        }

        // Collapsed state: time only.
        Column {
            anchors.centerIn: parent
            spacing: -4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.clockText
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: 19
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }

            Text {
                visible: root.barExpanded
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateText
                color: Theme.textFaint
                font.family: Theme.mono
                font.pixelSize: 6
                font.letterSpacing: 0.8
            }
        }

        // Left: windows menu, radios, recent apps.
        Row {
            id: leftRow
            visible: root.barExpanded
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            RingBadge {
                id: windowsButton
                icon: "windows"
                button: true
                badgeText: WindowModel.count > 0 ? String(WindowModel.count).padStart(2, "0") : ""
                active: root.activePanel === "windows"
                onClicked: root.togglePanel("windows", windowsButton)
            }

            RingBadge {
                id: bluetoothChip
                visible: System.bluetoothAvailable
                icon: "bluetooth"
                button: true
                lit: System.bluetoothEnabled
                active: root.activePanel === "bluetooth"
                onClicked: root.togglePanel("bluetooth", bluetoothChip)
            }

            RingBadge {
                id: networkChip
                icon: System.wifiConnected ? "wifi" : "wifi-off"
                value: System.wifiConnected ? System.wifiSignal / 100.0 : 0
                active: root.activePanel === "network"
                warning: System.wifiEnabled && !System.wifiConnected
                onClicked: root.togglePanel("network", networkChip)
            }

            Row {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: RecentApps

                    delegate: RecentAppButton {
                        id: recentButton
                        required property int index
                        required property var model

                        visible: index < 3
                        width: visible ? 38 : 0
                        appName: model.appName
                        appIcon: model.icon
                        windowCount: model.windowCount
                        active: model.active

                        onClicked: {
                            if (model.windowCount === 1)
                                RecentApps.activateWindow(index, 0)
                            else
                                root.showGroup(index, model.windows, model.appName, recentButton)
                        }
                        onHoveredChanged: hovered => {
                            if (hovered)
                                root.showGroup(index, model.windows, model.appName, recentButton)
                            else
                                root.scheduleHideGroup()
                        }
                    }
                }
            }
        }

        // Right: audio, battery, tray, power.
        Row {
            id: rightRow
            visible: root.barExpanded
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            RingBadge {
                id: volumeChip
                icon: System.muted ? "volume-mute" : "volume"
                value: System.muted ? 0 : System.volume / 100.0
                active: root.activePanel === "volume"
                warning: System.muted
                onClicked: root.togglePanel("volume", volumeChip)
                onWheeled: wheel => System.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5)
            }

            RingBadge {
                id: batteryChip
                visible: System.batteryPresent
                icon: System.charging ? "bolt" : "battery"
                value: System.batteryPercent / 100.0
                active: root.activePanel === "battery"
                warning: System.batteryPercent <= 18 && !System.charging
                charging: System.charging
                onClicked: root.togglePanel("battery", batteryChip)
            }

            Item {
                width: 1
                height: 32
                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: 18
                    color: Theme.line
                }
            }

            Row {
                spacing: 0

                Repeater {
                    model: TrayModel

                    delegate: Item {
                        id: trayIcon
                        required property int index
                        required property var model

                        visible: index < 3
                        width: visible ? 19 : 0
                        height: 32

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 6
                            color: trayMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) : "transparent"
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            visible: model.iconName.length > 0
                            width: 14
                            height: 14
                            source: model.iconName
                        }

                        IconGlyph {
                            anchors.centerIn: parent
                            visible: model.iconName.length === 0
                            name: "diamond"
                            width: 11
                            height: 11
                            color: Theme.textDim
                        }

                        Rectangle {
                            visible: model.attention
                            width: 3
                            height: 3
                            radius: 1.5
                            color: Theme.warning
                            anchors.right: parent.right
                            anchors.rightMargin: 1
                            anchors.top: parent.top
                            anchors.topMargin: 3
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
                width: 20
                height: 32

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 6
                    color: drawerMouse.containsMouse || root.activePanel === "tray"
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.09) : "transparent"
                }

                IconGlyph {
                    anchors.centerIn: parent
                    name: "tray"
                    width: 12
                    height: 12
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

            RingBadge {
                id: powerButton
                icon: "bolt"
                button: true
                active: root.activePanel === "power"
                onClicked: root.togglePanel("power", powerButton)
            }
        }
    }

    // Bar shadow sits outside the clipped bar content so its soft edge is not
    // cut off during the width animation.
    RectangularShadow {
        visible: !root.hudHidden
        anchors.fill: bar
        radius: bar.height / 2
        blur: 18
        spread: 1
        color: "#55000000"
        offset: Qt.vector2d(0, 3)
        z: 19
    }

    // Hover flyout for a multi-window app group.
    GroupPopup {
        id: groupPopup
        visible: root.groupPopupVisible
        x: bar.x + root.groupPopupX
        y: bar.y - height - 8
        z: 25
        appName: root.groupAppName
        windows: root.groupWindows
        groupIndex: root.groupPopupGroup
        onHoveredChanged: hovered => {
            root.groupPopupHovered = hovered
            if (hovered)
                groupHideTimer.stop()
            else
                root.scheduleHideGroup()
        }
        onActivated: windowIndex => {
            RecentApps.activateWindow(root.groupPopupGroup, windowIndex)
            root.hideGroup()
        }
    }

    // ---------------------------------------------------------------------
    // Secondary panels
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

    BluetoothPanel {
        z: 30
        isActive: root.activePanel === "bluetooth"
        x: root.panelX
        y: root.panelBottom - height
        onCloseRequested: root.closePanels()
    }

    NetworkPanel {
        z: 30
        isActive: root.activePanel === "network"
        x: root.panelX
        y: root.panelBottom - height
        onCloseRequested: root.closePanels()
        onKeyboardRequested: requested => root.keyboardRequested = requested
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
        z: 30
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
        y: root.height - root.barHeight - root.bottomGap - 34
        z: 50
        message: root.toastMessage
        success: root.toastSuccess
        shown: root.toastShown && root.overlay
    }
}
