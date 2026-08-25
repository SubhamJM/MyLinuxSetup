import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import "./modules"
import "./" // Imports NotchConfig singleton

ShellRoot {
    id: root

    property string activeMode: "idle"
    property string previousExpandedMode: "launcher"
    property bool isWorkspacePeeking: false
    property bool isScreenRecording: false
    property bool openedViaShortcut: false

    // Persistent notifications store
    ListModel {
        id: globalNotifModel
    }

    // Notification Island Banner State
    property string notifPopupSummary: ""
    property string notifPopupBody: ""
    property string notifPopupApp: ""
    property bool isNotifPopupActive: notifPopupSummary !== ""

    Timer {
        id: notifPopupTimer
        interval: NotchConfig.timerNotifPopup
        repeat: false
        onTriggered: {
            root.notifPopupSummary = "";
            root.notifPopupBody = "";
            root.notifPopupApp = "";
            if (root.activeMode === "idle" && !notchHoverHandler.hovered) {
                root.collapseToIdle();
            }
        }
    }

    property bool isServerReady: false

    Timer {
        id: startupGraceTimer
        interval: NotchConfig.timerStartupGrace
        running: true
        repeat: false
        onTriggered: root.isServerReady = true
    }

    // Native D-Bus Notification Server
    NotificationServer {
        id: notifServer

        onNotification: (notification) => {
            notification.tracked = true;

            var summaryText = notification.summary || "";
            var bodyText = notification.body || "";
            var appNameText = notification.appName || "System";
            var appIconText = notification.appIcon || "";

            var exists = false;
            for (var i = 0; i < globalNotifModel.count; i++) {
                var item = globalNotifModel.get(i);
                if (item.summary === summaryText && item.body === bodyText && item.appName === appNameText) {
                    exists = true;
                    break;
                }
            }

            if (!exists) {
                globalNotifModel.insert(0, {
                    "summary": summaryText,
                    "body": bodyText,
                    "appName": appNameText,
                    "appIcon": appIconText,
                    "notifObj": notification
                });
            }

            if (root.isServerReady) {
                root.notifPopupSummary = summaryText !== "" ? summaryText : appNameText;
                root.notifPopupBody = bodyText;
                root.notifPopupApp = appNameText;
                notifPopupTimer.restart();
            }
        }
    }

    readonly property bool isDashMode: activeMode === "idle" || activeMode === "hover"

    function collapseToIdle() {
        root.isWorkspacePeeking = false;
        root.openedViaShortcut = false;
        root.activeMode = "idle";
    }

    function switchMode(newMode, fromShortcut = false) {
        root.isWorkspacePeeking = false;
        if (root.activeMode === newMode) {
            root.collapseToIdle();
        } else {
            root.openedViaShortcut = fromShortcut;
            root.activeMode = newMode;
        }
    }

	function regainFocus() {
		if (activeMode === "switcher" && typeof switcherMod !== "undefined") switcherMod.forceActiveFocus();
		else if (activeMode === "launcher") launcherMod.searchInput.forceActiveFocus();
        else if (activeMode === "theme") themeMod.themeList.forceActiveFocus();
        else if (activeMode === "wallpaper") wallMod.wallpaperGrid.forceActiveFocus();
        else if (activeMode === "transition") transMod.transitionGrid.forceActiveFocus();
        else if (activeMode === "clipboard" && typeof clipMod !== "undefined") clipMod.searchInput.forceActiveFocus();
        else if (activeMode === "shelf" && typeof shelfMod !== "undefined") shelfMod.forceShelfFocus();
        else if (activeMode === "powermenu" && typeof powerMod !== "undefined") powerMod.forceActiveFocus();
    }

    onActiveModeChanged: {
        if (activeMode !== "idle" && activeMode !== "hover" && activeMode !== "osd") {
            root.previousExpandedMode = activeMode;
        }

        if (activeMode === "idle") {
            root.openedViaShortcut = false;
        } else if (activeMode === "wifi") {
            wifiMod.activeTab = "wifi";
            wifiMod.refreshStatus();
        } else if (activeMode === "bluetooth" && typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = true;
        } else if (typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = false;
        }

        Qt.callLater(() => {
            root.regainFocus();
            if (activeMode !== "launcher") launcherMod.searchInput.text = "";
            if (activeMode !== "clipboard" && typeof clipMod !== "undefined") clipMod.searchInput.text = "";
            if (activeMode !== "shelf" && typeof shelfMod !== "undefined") shelfMod.searchInput.text = "";
        });
    }

    // ========================================================
    // CENTRALIZED DIMENSIONS RESOLUTION (from NotchConfig)
    // ========================================================
    readonly property int targetWidth: {
        if (isDashMode && typeof dashMod !== "undefined") {
            return dashMod.implicitWidth;
        }
        return NotchConfig.modeDimensions[activeMode]?.width ?? NotchConfig.modeDimensions["idle"].width;
    }
    
    readonly property int targetHeight: {
        if (root.isNotifPopupActive && root.isDashMode) {
            return NotchConfig.heightNotifBanner;
        }
        if (activeMode === "transition" || activeMode === "calendar" || activeMode === "powermenu" || activeMode === "battery") {
            return NotchConfig.modeDimensions[activeMode]?.height ?? 220;
        }
        if (activeMode === "notifications") {
            return NotchConfig.calculateNotificationsHeight(globalNotifModel.count);
        }
        if (activeMode === "shelf") {
            return NotchConfig.calculateShelfHeight(typeof shelfMod !== "undefined" ? shelfMod.calculatedCount : 0);
        }
        if (activeMode === "clipboard") {
            return NotchConfig.calculateClipboardHeight(typeof clipMod !== "undefined" ? clipMod.calculatedCount : 0);
        }
        if (activeMode === "recorder") {
            return typeof recMod !== "undefined" 
                ? NotchConfig.calculateRecorderHeight(recMod.recordAudio, recMod.isMicDropdownOpen) 
                : 225;
        }
        if (activeMode === "launcher") {
            return NotchConfig.calculateLauncherHeight(launcherMod.calculatedCount, launcherMod.allApps.length);
        }
        if (activeMode === "bluetooth") {
            return NotchConfig.calculateBluetoothHeight(btMod.filteredDevices, btMod.stateMap);
        }
        if (activeMode === "wifi") {
            return NotchConfig.calculateWifiHeight(wifiMod.activeTab, wifiMod.wifiEnabled, wifiMod.model.count, wifiMod.listViewContentHeight);
        }
        return NotchConfig.modeDimensions[activeMode]?.height ?? NotchConfig.modeDimensions["idle"].height;
    } 

    readonly property int targetRadius: NotchConfig.modeDimensions[activeMode]?.radius ?? NotchConfig.modeDimensions["idle"].radius
    readonly property int cornerCurveRadius: NotchConfig.cornerCurveRadius

    // OSD Engine
    property string osdType: "volume"
    property int osdValue: 50
    property bool osdReady: false

    function triggerOsd(type, val) {
        root.osdType = type;
        root.osdValue = Math.max(0, Math.min(100, val));
        if (root.activeMode !== "osd") {
            root.osdReady = false;
            root.activeMode = "osd";
            osdSettleTimer.restart();
        } else {
            root.osdReady = true;
        }
        osdHideTimer.restart();
    }

    Timer { id: osdSettleTimer; interval: NotchConfig.timerOsdSettle; onTriggered: root.osdReady = true }
    Timer { id: osdHideTimer; interval: NotchConfig.timerOsdHide; onTriggered: { if (root.activeMode === "osd") { root.collapseToIdle(); root.osdReady = false; } } }
    
    Process {
        id: osdFileReader
        running: false
        command: ["sh", "-c", "cat /tmp/notch_osd 2>/dev/null && : > /tmp/notch_osd"]
        stdout: StdioCollector {
            onStreamFinished: {
                var content = this.text.trim();
                if (content !== "") {
                    var parts = content.split(" ");
                    if (parts.length >= 2) {
                        var val = parseInt(parts[1]);
                        if (!isNaN(val)) root.triggerOsd(parts[0], val);
                    }
                }
            }
        }
    }

    Timer { interval: NotchConfig.timerPollOsd; running: true; repeat: true; onTriggered: if (!osdFileReader.running) osdFileReader.running = true }

    Timer {
        id: workspaceSwitchSettleTimer
        interval: NotchConfig.timerWorkspacePeek; repeat: false
        onTriggered: {
            if (root.isWorkspacePeeking) {
                root.isWorkspacePeeking = false;
                if (root.activeMode === "hover" && !notchHoverHandler.hovered) root.collapseToIdle();
            }
        }
    }

    Connections {
        target: typeof Hyprland !== "undefined" ? Hyprland : null
        function onRawEvent(name, data) {
            if (name === "workspace" || name === "focusedmon") {
                if (root.activeMode === "idle") {
                    root.isWorkspacePeeking = true;
                    root.activeMode = "hover";
                    workspaceSwitchSettleTimer.restart();
                } else if (root.isWorkspacePeeking) {
                    workspaceSwitchSettleTimer.restart();
                }
            }
        }
    }

    // Global Shortcuts
    GlobalShortcut { name: "toggleNotchLauncher"; onPressed: root.switchMode("launcher", true) }
    GlobalShortcut { name: "toggleThemeNotch"; onPressed: root.switchMode("theme", true) }
    GlobalShortcut { name: "toggleWallpaperNotch"; onPressed: root.switchMode("wallpaper", true) }
    GlobalShortcut { name: "toggleTransitionNotch"; onPressed: root.switchMode("transition", true) }
    GlobalShortcut { name: "resetNotchToIdle"; onPressed: root.collapseToIdle() }
    GlobalShortcut { name: "toggleRecorderNotch"; onPressed: root.switchMode("recorder", true) }
    GlobalShortcut { name: "togglePowerMenuNotch"; onPressed: root.switchMode("powermenu", true) }
    GlobalShortcut { name: "toggleCalendarNotch"; onPressed: root.switchMode("calendar", true) }
    GlobalShortcut { name: "toggleClipboardNotch"; onPressed: root.switchMode("clipboard", true) }
    GlobalShortcut { name: "toggleShelfNotch"; onPressed: root.switchMode("shelf", true) }
    GlobalShortcut { name: "toggleNotificationsNotch"; onPressed: root.switchMode("notifications", true) }
	GlobalShortcut { name: "toggleMusicInfoNotch"; onPressed: if (typeof dashMod !== "undefined") dashMod.showMusicInfo = !dashMod.showMusicInfo }
	GlobalShortcut { 
        name: "cycleWindowNext"
        onPressed: {
            if (root.activeMode !== "switcher") {
                root.switchMode("switcher", true);
                switcherMod.refreshClients();
            } else {
                switcherMod.cycleNext();
            }
        }
    }

    GlobalShortcut { 
        name: "cycleWindowPrev"
        onPressed: {
            if (root.activeMode === "switcher") {
                switcherMod.cyclePrev();
            }
        }
	}

	GlobalShortcut {
        name: "confirmAltRelease"
        onPressed: {
            if (root.activeMode === "switcher") {
                switcherMod.activateSelected();
            }
        }
    }

    // Main Notch Panel
    PanelWindow {
        id: panel
        anchors.top: true
        implicitWidth: 860
        implicitHeight: 520
        exclusiveZone: NotchConfig.baseExclusiveZone
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay

        mask: Region {
            item: notchContainer
        }

        WlrLayershell.keyboardFocus: (root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "osd") 
            ? WlrKeyboardFocus.Exclusive 
            : WlrKeyboardFocus.None

        Item {
            id: notchContainer
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: notch.width + (root.cornerCurveRadius * 2)
            height: notch.height

            focus: root.activeMode !== "idle" && root.activeMode !== "hover"
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.collapseToIdle();
                    event.accepted = true;
                } else {
                    root.regainFocus();
                }
            }

            DropArea {
                id: notchDropArea
                anchors.fill: parent
                keys: ["text/uri-list"]

                onEntered: (drag) => {
                    if (drag.hasUrls) {
                        if (root.activeMode !== "shelf") {
                            root.switchMode("shelf", false);
                        }
                        drag.acceptProposedAction();
                    }
                }

                onDropped: (drop) => {
                    if (drop.hasUrls && typeof shelfMod !== "undefined") {
                        shelfMod.addDroppedFiles(drop.urls);
                        drop.acceptProposedAction();
                    }
                }
            }

            // Left Wing
            Canvas {
                id: leftWing
                width: root.cornerCurveRadius; height: root.cornerCurveRadius
                anchors.top: parent.top; anchors.right: notch.left; anchors.rightMargin: -1 
                renderTarget: Canvas.FramebufferObject

                Connections { target: Theme; function onThemeReloaded() { leftWing.requestPaint(); } }
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Theme.colors.bg ?? "#12141c";
                    ctx.beginPath();
                    ctx.moveTo(width + 1, 0); ctx.lineTo(width + 1, height);
                    ctx.arcTo(width, 0, 0, 0, height);
                    ctx.closePath(); ctx.fill();
                }
            }

            // Right Wing
            Canvas {
                id: rightWing
                width: root.cornerCurveRadius; height: root.cornerCurveRadius
                anchors.top: parent.top; anchors.left: notch.right; anchors.leftMargin: -1 
                renderTarget: Canvas.FramebufferObject

                Connections { target: Theme; function onThemeReloaded() { rightWing.requestPaint(); } }
                Component.onCompleted: rightWing.requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Theme.colors.bg ?? "#12141c";
                    ctx.beginPath();
                    ctx.moveTo(-1, 0); ctx.lineTo(-1, height);
                    ctx.arcTo(0, 0, width, 0, height);
                    ctx.closePath(); ctx.fill();
                }
            }

            MouseArea {
                id: extendedHoverArea
                anchors.fill: notch
                anchors.margins: -20
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                enabled: root.activeMode === "wifi" || root.activeMode === "bluetooth" || root.activeMode === "battery" || root.activeMode === "shelf" || root.activeMode === "notifications"
                onContainsMouseChanged: {
                    if (containsMouse) {
                        autoCollapseTimer.stop();
                    } else if (!notchHoverHandler.hovered && !root.openedViaShortcut) {
                        autoCollapseTimer.restart();
                    }
                }
            }

            // Notch Surface
            Rectangle {
                id: notch
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: root.targetHeight
                color: Theme.colors.bg ?? "#12141c"
                clip: true
                
                radius: 0
                bottomLeftRadius: root.targetRadius
                bottomRightRadius: root.targetRadius
                Behavior on width  { NumberAnimation { duration: NotchConfig.animNotchResize; easing.type: Easing.OutExpo } }
                Behavior on height { NumberAnimation { duration: NotchConfig.animNotchResize; easing.type: Easing.OutExpo } }

                // 1. Persistent Dash Layer
                Item {
                    id: dashContainer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.targetHeight
                    z: 5

                    opacity: root.isDashMode ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on height { NumberAnimation { duration: NotchConfig.animNotchResize; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: NotchConfig.animDashFade; easing.type: Easing.OutQuad } }

                    MainDash { 
                        id: dashMod 
                        anchors.fill: parent
                    }
                }

                // 2. Expanded Modules Container
                Item {
                    id: modulesContainer
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: root.activeMode === "osd" ? 6 : 12
                    anchors.bottomMargin: root.activeMode === "osd" ? 6 : 12
                    z: 2

                    opacity: (!root.isDashMode && (notch.height > 35 || root.activeMode === "osd")) ? 1.0 : 0.0
                    visible: opacity > 0.001
                    enabled: !root.isDashMode
                    Behavior on opacity { NumberAnimation { duration: NotchConfig.animModulesFade; easing.type: Easing.OutQuad } }

                    StackLayout {
                        id: contentStack
                        anchors.fill: parent

                        currentIndex: {
                            var mode = root.isDashMode ? root.previousExpandedMode : root.activeMode;
                            switch(mode) {
                                case "launcher":      return 0;
                                case "theme":         return 1;
                                case "wallpaper":     return 2;
                                case "transition":    return 3;
                                case "osd":           return 4;
                                case "bluetooth":     return 5;
                                case "wifi":          return 6;
                                case "recorder":      return 7;
                                case "battery":       return 8;
                                case "powermenu":     return 9;
                                case "calendar":      return 10;
                                case "clipboard":     return 11;
                                case "shelf":         return 12;
								case "notifications": return 13;
								case "switcher":      return 14;
                                default:              return 0;
                            }
                        }

                        Launcher           { id: launcherMod }
                        ThemeSelector      { id: themeMod }
                        WallpaperSelector  { id: wallMod }
                        TransitionSelector { id: transMod }
                        Osd                { id: osdMod }
                        BluetoothModule    { id: btMod }
                        WifiModule         { id: wifiMod }
                        RecorderModule     { id: recMod }
                        BatteryModule      { id: battMod }
                        PowerMenu          { id: powerMod }
                        CalendarModule     { id: calMod }
                        ClipboardModule    { id: clipMod }
                        ShelfModule        { id: shelfMod }
						NotificationModule { id: notifMod }
						WindowSwitcher     { id: switcherMod }
                    }
                }

                Timer {
                    id: autoCollapseTimer
                    interval: NotchConfig.timerAutoCollapse
                    repeat: false
                    onTriggered: {
                        if (root.openedViaShortcut) return;
                        if (!notchHoverHandler.hovered && (!extendedHoverArea.enabled || !extendedHoverArea.containsMouse) && root.activeMode !== "idle" && root.activeMode !== "osd" && !root.isWorkspacePeeking) {
                            root.collapseToIdle();
                        }
                    }
                }

                HoverHandler {
                    id: notchHoverHandler
                    enabled: root.activeMode !== "osd"
                    onHoveredChanged: {
                        if (hovered) {
                            autoCollapseTimer.stop();
                            root.isWorkspacePeeking = false;
                            if (root.activeMode === "idle") root.activeMode = "hover";
                        } else {
                            if (!root.openedViaShortcut && (!extendedHoverArea.enabled || !extendedHoverArea.containsMouse)) {
                                autoCollapseTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }
}
