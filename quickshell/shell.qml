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
    property string previousExpandedMode: "theme"
    property bool isWorkspacePeeking: false
    property bool isScreenRecording: false
    property int screenRecordSeconds: typeof recMod !== "undefined" ? recMod.recordSeconds : 0

    function formatRecTime(sec) {
        var s = sec || 0;
        var m = Math.floor(s / 60);
        var remSec = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (remSec < 10 ? "0" : "") + remSec;
    }
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

    property bool dndEnabled: false



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

            if (root.isServerReady && !root.dndEnabled) {
                root.notifPopupSummary = summaryText !== "" ? summaryText : appNameText;
                root.notifPopupBody = bodyText;
                root.notifPopupApp = appNameText;
                notifPopupTimer.restart();
            }
        }
    }

    readonly property bool isDashMode: activeMode === "idle" || activeMode === "hover"
    readonly property bool isPopupMode: activeMode === "launcher" || activeMode === "wifi" || activeMode === "bluetooth" || activeMode === "utility" || activeMode === "battery" || activeMode === "recorder" || activeMode === "calendar" || activeMode === "notifications" || activeMode === "shelf" || activeMode === "notes" || activeMode === "cheatsheet" || activeMode === "clipboard" || activeMode === "hover" || activeMode === "music"

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

    function openUtility(section = "", fromShortcut = false) {
        root.isWorkspacePeeking = false;
        if (root.activeMode === "utility" && typeof utilMod !== "undefined" && utilMod.activeSection === section) {
            root.collapseToIdle();
        } else {
            if (typeof utilMod !== "undefined") {
                utilMod.activeSection = section;
            }
            root.openedViaShortcut = fromShortcut;
            root.activeMode = "utility";
        }
    }

	function regainFocus() {
        if (activeMode === "launcher" && typeof launcherMod !== "undefined") launcherMod.searchInput.forceActiveFocus();
		else if (activeMode === "switcher" && typeof switcherMod !== "undefined") switcherMod.forceActiveFocus();
        else if (activeMode === "theme" && typeof themeMod !== "undefined") themeMod.forceThemeFocus();
        else if (activeMode === "wallpaper") wallMod.wallpaperGrid.forceActiveFocus();
        else if (activeMode === "transition") transMod.transitionGrid.forceActiveFocus();
        else if (activeMode === "clipboard" && typeof clipMod !== "undefined") clipMod.searchInput.forceActiveFocus();
        else if (activeMode === "shelf" && typeof shelfMod !== "undefined") shelfMod.forceShelfFocus();
        else if (activeMode === "powermenu" && typeof powerMod !== "undefined") powerMod.forceActiveFocus();
        else if (activeMode === "notes" && typeof notesMod !== "undefined") notesMod.forceNotesFocus();
        else if (activeMode === "cheatsheet" && typeof cheatsheetMod !== "undefined") cheatsheetMod.forceSearchFocus();
        else if (activeMode === "music" && typeof musicMod !== "undefined") musicMod.forceActiveFocus();
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

        if (activeMode === "launcher") {
            if (typeof launcherMod !== "undefined") launcherMod.onOpened();
        }

        Qt.callLater(() => {
            root.regainFocus();
            if (activeMode !== "launcher" && typeof launcherMod !== "undefined") launcherMod.searchInput.text = "";
            if (activeMode !== "theme" && typeof themeMod !== "undefined") themeMod.resetSearch();
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
        if (activeMode === "notes" && typeof notesMod !== "undefined" && notesMod.isWideMode) {
            return 820;
        }
        var dim = NotchConfig.modeDimensions[activeMode];
        return dim && dim.width !== undefined ? dim.width : NotchConfig.modeDimensions["idle"].width;
    }
    
    readonly property int targetHeight: {
        if (root.isNotifPopupActive && root.isDashMode) {
            return 42;
        }
        if (activeMode === "cheatsheet" && typeof cheatsheetMod !== "undefined" && cheatsheetMod.isAddingMode) {
            return 500;
        }
        if (activeMode === "launcher") {
            return typeof launcherMod !== "undefined"
                ? NotchConfig.calculateLauncherHeight(launcherMod.calculatedCount, launcherMod.allApps.length)
                : 360;
        }
        if (activeMode === "transition" || activeMode === "calendar" || activeMode === "powermenu" || activeMode === "battery" || activeMode === "notes" || activeMode === "cheatsheet") {
            var mDim = NotchConfig.modeDimensions[activeMode];
            return mDim && mDim.height !== undefined ? mDim.height : 220;
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
                ? NotchConfig.calculateRecorderHeight(recMod.recordAudio, recMod.isMicDropdownOpen, recMod.isRecording) 
                : 270;
        }
        if (activeMode === "bluetooth") {
            return NotchConfig.calculateBluetoothHeight(btMod.filteredDevices, btMod.stateMap);
        }
        if (activeMode === "wifi") {
            return NotchConfig.calculateWifiHeight(wifiMod.activeTab, wifiMod.wifiEnabled, wifiMod.model.count, wifiMod.listViewContentHeight);
        }
        if (activeMode === "utility") {
            return typeof utilMod !== "undefined"
                ? NotchConfig.calculateUtilityHeight(utilMod.activeSection)
                : 400;
        }
        if (activeMode === "music") {
            return typeof musicMod !== "undefined" ? musicMod.calculatedHeight : 335;
        }
        if (activeMode === "idle") {
            return 32;
        }
        if (activeMode === "hover") {
            return 42;
        }
        var hDim = NotchConfig.modeDimensions[activeMode];
        return hDim && hDim.height !== undefined ? hDim.height : NotchConfig.modeDimensions["idle"].height;
    } 

    readonly property int targetRadius: {
        if (dashMod.isIslandActive || (root.isNotifPopupActive && root.isDashMode)) {
            return 21;
        }
        if (activeMode === "idle") {
            return 16;
        }
        if (activeMode === "hover") {
            return 21;
        }
        if (activeMode === "utility") {
            return 28;
        }
        if (activeMode === "music") {
            return 26;
        }
        var rDim = NotchConfig.modeDimensions[activeMode];
        return rDim && rDim.radius !== undefined ? rDim.radius : NotchConfig.modeDimensions["idle"].radius;
    }
    readonly property int cornerCurveRadius: NotchConfig.cornerCurveRadius

    // OSD Engine
    property string osdType: "volume"
    property int osdValue: 50
    property string previousActiveMode: "idle"
    readonly property bool isOsdMode: activeMode === "osd" || previousActiveMode === "osd"

    function triggerOsd(type, val) {
        root.osdType = type;
        root.osdValue = Math.max(0, Math.min(100, val));
        if (typeof utilMod !== "undefined" && utilMod !== null) {
            if (type === "volume") {
                utilMod.audioVolume = root.osdValue / 100.0;
                utilMod.audioMuted = (root.osdValue <= 0);
            } else if (type === "brightness") {
                utilMod.displayBrightness = Math.max(0.01, root.osdValue / 100.0);
            }
        }
        if (root.activeMode !== "osd") {
            root.previousActiveMode = root.activeMode;
            root.activeMode = "osd";
        }
        osdHideTimer.restart();
    }

    Timer {
        id: osdResetPrevModeTimer
        interval: 240
        onTriggered: {
            if (root.previousActiveMode === "osd" && root.activeMode !== "osd") {
                root.previousActiveMode = root.activeMode;
            }
        }
    }

    Timer {
        id: osdHideTimer
        interval: NotchConfig.timerOsdHide
        onTriggered: {
            if (root.activeMode === "osd") {
                root.previousActiveMode = "osd";
                root.collapseToIdle();
                osdResetPrevModeTimer.restart();
            }
        }
    }
    
    Process {
        id: osdListener
        running: true
        command: ["python3", "-u", "-c", `
import os
p = '/tmp/notch_osd'
try:
    if os.path.exists(p) and not os.path.islink(p):
        os.remove(p)
    os.mkfifo(p)
except Exception:
    pass
while True:
    try:
        with open(p, 'r') as f:
            for line in f:
                l = line.strip()
                if l: print(l, flush=True)
    except Exception:
        pass
`]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                var content = data.trim();
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

    Process {
        id: modeListener
        running: true
        command: ["python3", "-u", "-c", `
import os
p = '/tmp/notch_mode'
try:
    if os.path.exists(p) and not os.path.islink(p):
        os.remove(p)
    os.mkfifo(p)
except Exception:
    pass
while True:
    try:
        with open(p, 'r') as f:
            for line in f:
                l = line.strip()
                if l: print(l, flush=True)
    except Exception:
        pass
`]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                var m = data.trim();
                if (m === "idle") {
                    root.collapseToIdle();
                } else if (m.startsWith("utility")) {
                    var parts = m.split(" ");
                    root.openUtility(parts.length > 1 ? parts[1] : "", true);
                } else if (m !== "") {
                    root.openedViaShortcut = true;
                    root.activeMode = m;
                }
            }
        }
    }

    Timer {
        id: workspaceSwitchSettleTimer
        interval: NotchConfig.timerWorkspacePeek
        repeat: false
        onTriggered: {
            root.isWorkspacePeeking = false;
        }
    }

    Connections {
        target: typeof Hyprland !== "undefined" ? Hyprland : null
        function onRawEvent(event) {
            var evName = (typeof event === "object" && event !== null) ? event.name : event;
            if (evName === "workspace" || evName === "focusedmon" || evName === "workspacev2") {
                if (typeof dashMod !== "undefined") dashMod.refreshWorkspaceIds();
                if (root.activeMode === "idle") {
                    root.isWorkspacePeeking = true;
                    workspaceSwitchSettleTimer.restart();
                } else if (root.isWorkspacePeeking) {
                    workspaceSwitchSettleTimer.restart();
                }
            }
        }
    }

    // Global Shortcuts
    GlobalShortcut {
        name: "toggleNotchLauncher"
        onPressed: {
            if (root.activeMode === "launcher") {
                root.collapseToIdle();
            } else {
                root.switchMode("launcher", true);
            }
        }
    }
    GlobalShortcut { name: "toggleThemeNotch"; onPressed: root.switchMode("theme", true) }
    GlobalShortcut { name: "toggleWallpaperNotch"; onPressed: root.switchMode("wallpaper", true) }
    GlobalShortcut { name: "toggleTransitionNotch"; onPressed: root.switchMode("transition", true) }
    GlobalShortcut { name: "resetNotchToIdle"; onPressed: root.collapseToIdle() }
    GlobalShortcut { name: "toggleBatteryNotch"; onPressed: root.switchMode("battery", true) }
    GlobalShortcut { name: "togglePowerMenuNotch"; onPressed: root.switchMode("powermenu", true) }
    GlobalShortcut { name: "toggleCalendarNotch"; onPressed: root.switchMode("calendar", true) }
    GlobalShortcut { name: "toggleClipboardNotch"; onPressed: root.switchMode("clipboard", true) }
    GlobalShortcut { name: "toggleShelfNotch"; onPressed: root.switchMode("shelf", true) }
    GlobalShortcut { name: "toggleNotificationsNotch"; onPressed: root.switchMode("notifications", true) }
    GlobalShortcut { name: "toggleDndNotch"; onPressed: root.dndEnabled = !root.dndEnabled }
    GlobalShortcut { 
        name: "toggleUtilityNotch"
        onPressed: root.openUtility("", true)
    }
    GlobalShortcut { 
        name: "toggleHoverNotch"
        onPressed: root.switchMode("hover", true)
    }
    GlobalShortcut { 
        name: "toggleMusicInfoNotch"
        onPressed: {
            if (root.activeMode === "music") {
                root.collapseToIdle();
            } else {
                root.switchMode("music", true);
            }
        }
    }
    GlobalShortcut { name: "toggleNotesNotch"; onPressed: root.switchMode("notes", true) }
    GlobalShortcut { name: "toggleCheatsheetNotch"; onPressed: root.switchMode("cheatsheet", true) }
    GlobalShortcut { 
        name: "toggleWifiNotch"
        onPressed: root.switchMode("wifi", true)
    }
    GlobalShortcut { 
        name: "toggleBluetoothNotch"
        onPressed: root.switchMode("bluetooth", true)
    }
    GlobalShortcut { 
        name: "toggleRecorderNotch"
        onPressed: root.switchMode("recorder", true)
    }
    GlobalShortcut { 
        name: "triggerScreenOcr"
        onPressed: {
            if (root.activeMode !== "idle" && root.activeMode !== "hover") {
                root.collapseToIdle();
            }
            if (typeof dashMod !== "undefined") dashMod.startOcr();
        }
    }
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

    IpcHandler {
        target: "notch"
        function switchMode(mode: string): string {
            root.switchMode(mode, true);
            return "OK";
        }
        function collapse(): string {
            root.collapseToIdle();
            return "OK";
        }
        function toggleMusic(): string {
            if (root.activeMode === "music") {
                root.collapseToIdle();
            } else {
                root.switchMode("music", true);
            }
            return "OK";
        }
        function toggleMusicPanel(panelName: string): string {
            if (root.activeMode !== "music") root.switchMode("music", true);
            if (typeof musicMod !== "undefined") musicMod.togglePanel(panelName);
            return "OK";
        }
        function toggleRecorder(): string {
            root.switchMode("recorder", true);
            return "OK";
        }
        function setScreenRecording(active: bool): string {
            root.isScreenRecording = active;
            if (typeof recMod !== "undefined") recMod.isRecording = active;
            return "OK";
        }
    }

    // Native Hyprland focus grabber: captures outside clicks and closes the expanded notch
    HyprlandFocusGrab {
        id: focusGrab
        active: !root.isDashMode && root.activeMode !== "osd" && (!shelfMod || !shelfMod.isDragging)
        windows: [panel]
        onCleared: {
            if (typeof shelfMod !== "undefined" && shelfMod.isDragging) return;
            root.collapseToIdle();
        }
    }

    // Permanent top reservation for Hyprland window tiling (32px)
    PanelWindow {
        id: reservationPanel
        anchors.top: true
        exclusiveZone: NotchConfig.baseExclusiveZone
        color: "transparent"
        Item { id: emptyResItem; width: 0; height: 0 }
        mask: Region { item: emptyResItem }
    }

    // Main Notch Panel
    PanelWindow {
        id: panel
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell"

        Item {
            id: fullMaskArea
            anchors.fill: parent
        }

        mask: Region {
            item: (root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "osd") 
                ? fullMaskArea 
                : notchContainer
        }

        WlrLayershell.keyboardFocus: (root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "osd") 
            ? WlrKeyboardFocus.OnDemand 
            : WlrKeyboardFocus.None

        // Fullscreen click-away backdrop: collapses any open popup/menu when clicking anywhere outside
        MouseArea {
            id: outsideClickCatcher
            anchors.fill: parent
            z: 0
            enabled: root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "osd"
            onClicked: {
                root.collapseToIdle();
            }
        }

        Item {
            id: notchContainer
            z: 1
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: notch.width + (root.cornerCurveRadius * 2)
            height: notch.height

            y: 0
            opacity: 1.0
            visible: true

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
                    if (typeof shelfMod !== "undefined" && shelfMod.isDragging) return;
                    if (drag.hasUrls) {
                        if (root.activeMode !== "shelf") {
                            root.switchMode("shelf", false);
                        }
                        drag.acceptProposedAction();
                    }
                }

                onDropped: (drop) => {
                    if (typeof shelfMod !== "undefined" && shelfMod.isDragging) return;
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
                    ctx.fillStyle = "#000000";
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
                    ctx.fillStyle = "#000000";
                    ctx.beginPath();
                    ctx.moveTo(-1, 0); ctx.lineTo(-1, height);
                    ctx.arcTo(0, 0, width, 0, height);
                    ctx.closePath(); ctx.fill();
                }
            }

            // Notch Surface
            Rectangle {
                id: notch
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: root.targetHeight
                color: "#000000"
                clip: true

                // Consumes clicks on empty space inside notch so they do not fall through to click-away catcher
                MouseArea {
                    anchors.fill: parent
                    z: -1
                }
                
                radius: 0
                bottomLeftRadius: root.targetRadius
                bottomRightRadius: root.targetRadius
                Behavior on width  { NumberAnimation { duration: root.isOsdMode ? 220 : NotchConfig.animNotchResize; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1] } }
                Behavior on height { NumberAnimation { duration: root.isOsdMode ? 220 : NotchConfig.animNotchResize; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1] } }

                // 1. Persistent Dash Layer
                Item {
                    id: dashContainer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.targetHeight
                    z: 5

                    opacity: (root.isDashMode && root.activeMode !== "osd") ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on height { NumberAnimation { duration: root.isOsdMode ? 220 : NotchConfig.animNotchResize; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: root.isOsdMode ? 140 : NotchConfig.animDashFade; easing.type: Easing.OutQuad } }

                    MainDash { 
                        id: dashMod 
                        anchors.fill: parent
                    }
                }

                // 2. Expanded Modules Container
                Item {
                    id: modulesContainer
                    anchors.fill: parent
                    anchors.leftMargin: root.activeMode === "music" ? 0 : 12
                    anchors.rightMargin: root.activeMode === "music" ? 0 : 12
                    anchors.topMargin: root.activeMode === "music" ? 0 : 12
                    anchors.bottomMargin: root.activeMode === "music" ? 0 : 12
                    z: 2

                    opacity: (!root.isDashMode && root.activeMode !== "osd" && notch.height > 35) ? 1.0 : 0.0
                    visible: opacity > 0.001
                    enabled: !root.isDashMode && root.activeMode !== "osd"
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
                                case "bluetooth":     return 4;
                                case "wifi":          return 5;
                                case "recorder":      return 6;
                                case "battery":       return 7;
                                case "powermenu":     return 8;
                                case "calendar":      return 9;
                                case "clipboard":     return 10;
                                case "shelf":         return 11;
								case "notifications": return 12;
								case "switcher":      return 13;
                                case "utility":       return 14;
                                case "music":         return 15;
                                case "notes":         return 16;
                                case "cheatsheet":    return 17;
                                default:              return 0;
                            }
                        }

                        Launcher           { id: launcherMod }
                        ThemeSelector      { id: themeMod }
                        WallpaperSelector  { id: wallMod }
                        TransitionSelector { id: transMod }
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
                        UtilityModule      { id: utilMod }
                        MusicModule        { id: musicMod }
                        NotesModule        { id: notesMod }
                        KeybindsModule     { id: cheatsheetMod }
                    }
                }

                // 3. Dedicated OSD HUD Layer
                Item {
                    id: osdContainer
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    z: 10

                    opacity: root.activeMode === "osd" ? 1.0 : 0.0
                    visible: opacity > 0.001
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                    Osd {
                        id: osdMod
                        anchors.fill: parent
                    }
                }

                HoverHandler {
                    id: notchHoverHandler
                    enabled: root.activeMode !== "osd"
                    onHoveredChanged: {
                        if (typeof shelfMod !== "undefined" && shelfMod.isDragging) return;
                        if (typeof utilMod !== "undefined" && (utilMod.isDraggingVolume || utilMod.isDraggingBrightness)) return;
                        if (hovered) {
                            root.openedViaShortcut = false;
                            root.isWorkspacePeeking = false;
                            if (root.activeMode === "idle") root.activeMode = "hover";
                        } else {
                            if (root.activeMode === "hover") {
                                root.collapseToIdle();
                            }
                        }
                    }
                }
            }
        }
    }
}
