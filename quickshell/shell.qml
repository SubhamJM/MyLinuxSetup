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

ShellRoot {
    id: root

    readonly property var modeDimensions: ({
        "idle":          { width: 120, height: 30,  radius: 12 },
        "hover":         { width: 460, height: 46,  radius: 12 },
        "launcher":      { width: 460, height: 360, radius: 12 },
        "theme":         { width: 440, height: 280, radius: 12 },
        "wallpaper":     { width: 760, height: 320, radius: 12 },
        "transition":    { width: 440, height: 320, radius: 12 },
        "osd":           { width: 280, height: 40,  radius: 16 },
        "wifi":          { width: 420, height: 380, radius: 12 }, 
        "bluetooth":     { width: 400, height: 360, radius: 12 },
        "recorder":      { width: 380, height: 225, radius: 12 },
        "battery":       { width: 380, height: 220, radius: 12 },
        "powermenu":     { width: 440, height: 100, radius: 14 },
        "calendar":      { width: 320, height: 280, radius: 12 },
        "clipboard":     { width: 460, height: 380, radius: 12 },
        "shelf":         { width: 460, height: 380, radius: 12 },
        "notifications": { width: 440, height: 380, radius: 12 }
    })

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
        interval: 1500
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
		interval: 800 // Ignore replayed notifications during the initial 800ms reload window
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

			// Check if already in the list to prevent duplicates on reload
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

			// Only pop up the banner if Quickshell has finished initializing
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
        if (activeMode === "launcher") launcherMod.searchInput.forceActiveFocus();
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

    readonly property int targetWidth: {
        if (isDashMode && typeof dashMod !== "undefined") {
            return dashMod.implicitWidth;
        }
        return modeDimensions[activeMode]?.width ?? modeDimensions["idle"].width;
    }
    
	readonly property int targetHeight: {
		if (root.isNotifPopupActive && root.isDashMode) {
			return 54; // Increase this value (e.g., 52 to 64) for a taller banner
		}
		if (activeMode === "transition") return 320;
        if (activeMode === "calendar") return 280;
        if (activeMode === "powermenu") return 100;
        if (activeMode === "battery") return 220;
        if (activeMode === "notifications") {
            if (globalNotifModel.count === 0) return 200;
            var notifCalcH = 50 + (globalNotifModel.count * 76);
            return Math.min(480, Math.max(200, notifCalcH));
        }
        if (activeMode === "shelf") {
            if (typeof shelfMod === "undefined" || shelfMod.calculatedCount === 0) return 220;
            var shelfCalcH = 66 + (shelfMod.calculatedCount * 48);
            return Math.min(440, Math.max(180, shelfCalcH));
        }
        if (activeMode === "clipboard") {
            if (typeof clipMod === "undefined" || clipMod.calculatedCount === 0) return 220;
            var clipCalcH = 66 + (clipMod.calculatedCount * 48);
            return Math.min(440, Math.max(180, clipCalcH));
        }
        if (activeMode === "recorder") {
            if (typeof recMod === "undefined") return 225;
            if (!recMod.recordAudio) return 205;
            if (recMod.isMicDropdownOpen) return 240 + Math.min(3, 4) * 32;
            return 245;
        }
        if (activeMode === "launcher") {
            if (launcherMod.calculatedCount === 0 && launcherMod.allApps.length === 0) return 320;
            var calculatedHeight = 66 + (launcherMod.calculatedCount * 48);
            return Math.min(420, Math.max(160, calculatedHeight));
        }
        if (activeMode === "bluetooth") {
            var btCount = btMod.filteredDevices.length;
            if (btCount === 0) return 266;

            var listItemsHeight = 0;
            for (var i = 0; i < btCount; i++) {
                var dev = btMod.filteredDevices[i];
                var expanded = btMod.stateMap[dev.mac] && btMod.stateMap[dev.mac].isExpanded;
                listItemsHeight += (expanded ? 84 : 48) + 6;
            }
            return Math.min(486, Math.max(246, 112 + listItemsHeight));
        }
        if (activeMode === "wifi") {
            if (wifiMod.activeTab === "hotspot") return 400;
            if (!wifiMod.wifiEnabled) return 226;
            if (wifiMod.model.count === 0) return 286;
            return Math.min(560, Math.max(200, 176 + wifiMod.listViewContentHeight));
        }
        return modeDimensions[activeMode]?.height ?? modeDimensions["idle"].height;
    } 

    readonly property int targetRadius: modeDimensions[activeMode]?.radius ?? modeDimensions["idle"].radius
    readonly property int cornerCurveRadius: 12

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

    Timer { id: osdSettleTimer; interval: 150; onTriggered: root.osdReady = true }
    Timer { id: osdHideTimer; interval: 2000; onTriggered: { if (root.activeMode === "osd") { root.collapseToIdle(); root.osdReady = false; } } }
    
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

    Timer { interval: 50; running: true; repeat: true; onTriggered: if (!osdFileReader.running) osdFileReader.running = true }

    Timer {
        id: workspaceSwitchSettleTimer
        interval: 1500; repeat: false
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

    // Main Notch Panel
    PanelWindow {
        id: panel
        anchors.top: true
        implicitWidth: 860
        implicitHeight: 520
        exclusiveZone: 30
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
                Behavior on width  { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

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
                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

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
                    Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

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
                    }
                }

                Timer {
                    id: autoCollapseTimer
                    interval: 60
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
