pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Window 2.15 as QW
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
    // The tallest panel is 470px; this is enough for the bar and all panels.
    // Keeping the transparent layer shorter saves a large full-screen buffer.
    readonly property int hudHeight: Math.min(screenH, 620)
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
    property bool volumeOsdVisible: false
    property int volumeOsdValue: 0
    property real volumeOsdOpacity: 0

    readonly property int barWidth: barExpanded ? expandedWidth : collapsedWidth
    readonly property bool hudHidden: WindowModel.fullScreenActive

    onHudHiddenChanged: {
        if (hudHidden) {
            volumeOsdTimer.stop()
            volumeOsdHideTimer.stop()
            volumeOsdVisible = false
            volumeOsdOpacity = 0
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
    height: hudHeight
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
        System.setVolumePanelActive(activePanel === "volume")
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
        const scale = 1.0
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

    function showVolumeOsd(value) {
        if (hudHidden || barExpanded)
            return
        volumeOsdValue = Math.round(value)
        volumeOsdVisible = true
        volumeOsdOpacity = 1
        volumeOsdTimer.restart()
        volumeOsdHideTimer.stop()
    }

    function hideVolumeOsd() {
        volumeOsdOpacity = 0
        volumeOsdHideTimer.restart()
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
        if (root.barExpanded) {
            volumeOsdTimer.stop()
            volumeOsdHideTimer.stop()
            volumeOsdVisible = false
            volumeOsdOpacity = 0
        } else {
            System.setVolumePanelActive(false)
        }
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
        function onVolumeActivity(volume) {
            if (!root.barExpanded && !root.hudHidden)
                root.showVolumeOsd(volume)
        }
    }


    Timer {
        id: volumeOsdTimer
        interval: 2000
        onTriggered: root.hideVolumeOsd()
    }

    Timer {
        id: volumeOsdHideTimer
        interval: 180
        onTriggered: root.volumeOsdVisible = false
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

        // Collapsed state: time only. The volume OSD cross-fades over it.
        Column {
            id: clockColumn
            anchors.centerIn: parent
            spacing: -4
            opacity: 1 - root.volumeOsdOpacity

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

        // Volume OSD shown over the collapsed capsule.
        Item {
            id: volumeOsd
            anchors.fill: parent
            visible: root.volumeOsdVisible
            opacity: root.volumeOsdOpacity
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Canvas {
                id: volumeRing
                anchors.fill: parent
                property real progress: Math.max(0, Math.min(1, root.volumeOsdValue / 100.0))
                onProgressChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    if (width <= 0 || height <= 0)
                        return
                    const inset = 4
                    const lw = 2
                    const x = inset
                    const y = inset
                    const w = width - inset * 2
                    const h = height - inset * 2
                    const r = h / 2
                    const straight = Math.max(0, w - 2 * r)
                    const vertical = Math.max(0, h - 2 * r)
                    const arc = Math.PI * r / 2
                    const total = 2 * straight + 2 * vertical + 4 * arc

                    function drawPath(fraction, color) {
                        if (fraction <= 0)
                            return
                        let remain = fraction * total
                        function line(x1, y1, x2, y2) {
                            if (remain <= 0)
                                return
                            const len = Math.hypot(x2 - x1, y2 - y1)
                            if (len <= 0)
                                return
                            const take = Math.min(remain, len)
                            const t = take / len
                            ctx.lineTo(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t)
                            remain -= take
                        }
                        function arcPart(cx, cy, start) {
                            if (remain <= 0)
                                return
                            const take = Math.min(remain, arc)
                            ctx.arc(cx, cy, r, start, start + take / r, false)
                            remain -= take
                        }

                        ctx.beginPath()
                        ctx.moveTo(x + r, y)
                        line(x + r, y, x + w - r, y)
                        arcPart(x + w - r, y + r, -Math.PI / 2)
                        line(x + w, y + r, x + w, y + h - r)
                        arcPart(x + w - r, y + h - r, 0)
                        line(x + w - r, y + h, x + r, y + h)
                        arcPart(x + r, y + h - r, Math.PI / 2)
                        line(x, y + h - r, x, y + r)
                        arcPart(x + r, y + r, Math.PI)
                        ctx.strokeStyle = color
                        ctx.lineWidth = lw
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }

                    drawPath(1, Theme.line)
                    drawPath(volumeRing.progress, Theme.accent)
                }
            }

            Text {
                anchors.centerIn: parent
                text: Math.round(root.volumeOsdValue) + "%"
                color: Theme.accent
                font.family: Theme.cjk
                font.pixelSize: 18
                font.weight: Font.Bold
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
    // Secondary panels are loaded on demand. Keeping eight full panel trees
    // alive for a collapsed bar costs several megabytes of QML objects and
    // delegate caches for no benefit.
    // ---------------------------------------------------------------------
    Loader {
        width: 500
        height: 380
        z: 30
        active: root.activePanel === "windows"
        sourceComponent: Component {
            WindowsPanel {
                isActive: true
                x: root.panelX
                y: root.panelBottom - height
                onCloseRequested: root.closePanels()
            }
        }
    }

    Loader {
        width: 360
        height: 415
        z: 30
        active: root.activePanel === "power"
        sourceComponent: Component {
            PowerPanel {
                isActive: true
                x: root.panelX
                y: root.panelBottom - height
                onCloseRequested: root.closePanels()
                onPowerRequested: (action, label) => {
                    System.powerAction(action)
                    root.closePanels()
                }
            }
        }
    }

    Loader {
        width: 390
        height: 430
        z: 30
        active: root.activePanel === "bluetooth"
        sourceComponent: Component {
            BluetoothPanel {
                isActive: true
                x: root.panelX
                y: root.panelBottom - height
                onCloseRequested: root.closePanels()
            }
        }
    }

    Loader {
        width: 430
        height: 470
        z: 30
        active: root.activePanel === "network"
        sourceComponent: Component {
            NetworkPanel {
                isActive: true
                x: root.panelX
                y: root.panelBottom - height
                onCloseRequested: root.closePanels()
                onKeyboardRequested: requested => root.keyboardRequested = requested
            }
        }
    }

    Loader {
        width: 360
        height: 440
        z: 30
        active: root.activePanel === "volume"
        sourceComponent: Component {
            VolumePanel {
                isActive: true
                x: root.panelX
                y: root.panelBottom - height
                onCloseRequested: root.closePanels()
            }
        }
    }

    Loader {
        width: 390
        height: 410
        z: 30
        active: root.activePanel === "battery"
        sourceComponent: Component {
            BatteryPanel {
                isActive: true
                x: root.panelX
                y: root.panelBottom - height
                onCloseRequested: root.closePanels()
            }
        }
    }

    Loader {
        width: 410
        height: 270
        z: 30
        active: root.activePanel === "tray"
        sourceComponent: Component {
            TrayPanel {
                isActive: true
                x: root.panelX
                y: root.panelBottom - height
                trayModel: TrayModel
                onCloseRequested: root.closePanels()
                onItemActivated: (service, button) => {
                    TrayMenu.activate(service, button)
                    root.closePanels()
                }
                onMenuRequested: (service, xInPanel) => {
                    root.openTrayMenu(service, root.panelX + xInPanel)
                }
            }
        }
    }

    Loader {
        width: 230
        height: 360
        z: 30
        active: root.activePanel === "trayMenu"
        sourceComponent: Component {
            TrayMenuPanel {
                service: root.trayService
                rootItems: root.trayItems
                visible: true
                opacity: 1
                x: Math.max(10, Math.min(root.width - width - 10, root.trayAnchorX - width + 30))
                y: root.panelBottom - height
                onCloseRequested: root.closePanels()
            }
        }
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
