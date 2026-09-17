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
        else if (activeMode === "theme" && typeof themeMod !== "undefined") themeMod.forceThemeFocus();
        else if (activeMode === "wallpaper") wallMod.wallpaperGrid.forceActiveFocus();
        else if (activeMode === "transition") transMod.transitionGrid.forceActiveFocus();
        else if (activeMode === "clipboard" && typeof clipMod !== "undefined") clipMod.searchInput.forceActiveFocus();
        else if (activeMode === "shelf" && typeof shelfMod !== "undefined") shelfMod.forceShelfFocus();
        else if (activeMode === "powermenu" && typeof powerMod !== "undefined") powerMod.forceActiveFocus();
        else if (activeMode === "notes" && typeof notesMod !== "undefined") notesMod.forceNotesFocus();
        else if (activeMode === "cheatsheet" && typeof cheatsheetMod !== "undefined") cheatsheetMod.forceSearchFocus();
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
        return NotchConfig.modeDimensions[activeMode]?.width ?? NotchConfig.modeDimensions["idle"].width;
    }
    
    readonly property int targetHeight: {
        if (root.isNotifPopupActive && root.isDashMode) {
            return NotchConfig.heightNotifBanner;
        }
        if (activeMode === "cheatsheet" && typeof cheatsheetMod !== "undefined" && cheatsheetMod.isAddingMode) {
            return 500;
        }
        if (activeMode === "transition" || activeMode === "calendar" || activeMode === "powermenu" || activeMode === "battery" || activeMode === "notes" || activeMode === "cheatsheet") {
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
    GlobalShortcut { name: "toggleNotchLauncher"; onPressed: root.switchMode("launcher", true) }
    GlobalShortcut { name: "toggleThemeNotch"; onPressed: root.switchMode("theme", true) }
    GlobalShortcut { name: "toggleWallpaperNotch"; onPressed: root.switchMode("wallpaper", true) }
    GlobalShortcut { name: "toggleTransitionNotch"; onPressed: root.switchMode("transition", true) }
    GlobalShortcut { name: "resetNotchToIdle"; onPressed: root.collapseToIdle() }
    GlobalShortcut { name: "toggleBatteryNotch"; onPressed: root.switchMode("battery", true) }
    GlobalShortcut { name: "toggleRecorderNotch"; onPressed: root.switchMode("recorder", true) }
    GlobalShortcut { name: "togglePowerMenuNotch"; onPressed: root.switchMode("powermenu", true) }
    GlobalShortcut { name: "toggleCalendarNotch"; onPressed: root.switchMode("calendar", true) }
    GlobalShortcut { name: "toggleClipboardNotch"; onPressed: root.switchMode("clipboard", true) }
    GlobalShortcut { name: "toggleShelfNotch"; onPressed: root.switchMode("shelf", true) }
    GlobalShortcut { name: "toggleNotificationsNotch"; onPressed: root.switchMode("notifications", true) }
    GlobalShortcut { name: "toggleDndNotch"; onPressed: root.dndEnabled = !root.dndEnabled }
    GlobalShortcut { name: "toggleUtilityNotch"; onPressed: root.switchMode("utility", true) }
    GlobalShortcut { name: "toggleMusicInfoNotch"; onPressed: root.switchMode("music", true) }
    GlobalShortcut { name: "toggleNotesNotch"; onPressed: root.switchMode("notes", true) }
    GlobalShortcut { name: "toggleCheatsheetNotch"; onPressed: root.switchMode("cheatsheet", true) }
    GlobalShortcut { name: "toggleWifiNotch"; onPressed: root.switchMode("wifi", true) }
    GlobalShortcut { name: "toggleBluetoothNotch"; onPressed: root.switchMode("bluetooth", true) }
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

    // Main Notch Panel
    PanelWindow {
        id: panel
        anchors.top: true
        implicitWidth: 880
        implicitHeight: 560
        exclusiveZone: NotchConfig.baseExclusiveZone
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell"

        mask: Region {
            item: notchContainer
        }

        WlrLayershell.keyboardFocus: (root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "osd") 
            ? WlrKeyboardFocus.OnDemand 
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
                enabled: false
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
                Behavior on width  { NumberAnimation { duration: root.isOsdMode ? 220 : NotchConfig.animNotchResize; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: root.isOsdMode ? 220 : NotchConfig.animNotchResize; easing.type: Easing.OutCubic } }

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
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
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

                Timer {
                    id: autoCollapseTimer
                    interval: NotchConfig.timerAutoCollapse
                    repeat: false
                    onTriggered: {
                        if (root.activeMode === "hover" && !notchHoverHandler.hovered) {
                            root.collapseToIdle();
                        }
                    }
                }

                HoverHandler {
                    id: notchHoverHandler
                    enabled: root.activeMode !== "osd"
                    onHoveredChanged: {
                        if (typeof shelfMod !== "undefined" && shelfMod.isDragging) return;
                        if (hovered) {
                            autoCollapseTimer.stop();
                            root.isWorkspacePeeking = false;
                            if (root.activeMode === "idle") root.activeMode = "hover";
                        } else {
                            if (root.activeMode === "hover") {
                                autoCollapseTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }
}
