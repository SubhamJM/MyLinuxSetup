import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth
import "./modules"

ShellRoot {
    id: root

    readonly property var modeDimensions: ({
        "idle":       { width: 120, height: 30,  radius: 12 },
        "hover":      { width: 440, height: 30,  radius: 12 },
        "launcher":   { width: 460, height: 360, radius: 12 },
        "theme":      { width: 400, height: 250, radius: 12 },
        "wallpaper":  { width: 760, height: 320, radius: 12 },
        "transition": { width: 420, height: 260, radius: 12 },
        "osd":        { width: 280, height: 40,  radius: 16 },
        "wifi":       { width: 420, height: 380, radius: 12 }, 
        "bluetooth":  { width: 400, height: 360, radius: 12 },
        "recorder":   { width: 380, height: 225, radius: 12 },
        "battery":    { width: 380, height: 188, radius: 12 },
        "powermenu":  { width: 342, height: 78,  radius: 14 },
        "calendar":   { width: 320, height: 280, radius: 12 }
    })

    property string activeMode: "idle"
    property string previousExpandedMode: "launcher"
    property bool isWorkspacePeeking: false
    property bool isScreenRecording: false
    property bool openedViaShortcut: false

    readonly property bool isDashMode: activeMode === "idle" || activeMode === "hover"

    function switchMode(newMode, fromShortcut = false) {
        root.isWorkspacePeeking = false;
        if (root.activeMode === newMode) {
            root.activeMode = "idle";
            root.openedViaShortcut = false;
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
        });
    }

    readonly property int targetWidth: {
        if (activeMode === "hover" && typeof dashMod !== "undefined") {
            return Math.max(modeDimensions["hover"].width, dashMod.implicitWidth);
        }
        return modeDimensions[activeMode]?.width ?? modeDimensions["idle"].width;
    }
    
    readonly property int targetHeight: {
        if (activeMode === "calendar") return 280;
        if (activeMode === "powermenu") return 78;
        if (activeMode === "battery") return 188;
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
            if (btCount === 0) return 220;
            return Math.min(440, Math.max(200, 66 + (btCount * 51)));
        }
        if (activeMode === "wifi") {
            if (wifiMod.activeTab === "hotspot") return 320;
            if (!wifiMod.wifiEnabled) return 180;
            if (wifiMod.model.count === 0) return 240;

            var listItemsHeight = 0;
            for (var i = 0; i < wifiMod.model.count; i++) {
                var item = wifiMod.model.get(i);
                var cardH = item.inUse ? 50 : (item.isExpanded ? (item.showPassword ? (item.hasError ? 138 : 116) : 84) : 48);
                listItemsHeight += (cardH + 6);
            }
            return Math.min(460, Math.max(200, 106 + listItemsHeight));
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
    Timer { id: osdHideTimer; interval: 2000; onTriggered: { if (root.activeMode === "osd") { root.activeMode = "idle"; root.osdReady = false; } } }
    
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
                if (root.activeMode === "hover" && !notchHoverHandler.hovered) root.activeMode = "idle";
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
    GlobalShortcut { name: "resetNotchToIdle"; onPressed: root.activeMode = "idle" }
    GlobalShortcut { name: "toggleRecorderNotch"; onPressed: root.switchMode("recorder", true) }
    GlobalShortcut { name: "togglePowerMenuNotch"; onPressed: root.switchMode("powermenu", true) }
    GlobalShortcut { name: "toggleCalendarNotch"; onPressed: root.switchMode("calendar", true) }

    // Invisible Fullscreen Backdrop
    PanelWindow {
        id: backdropPanel
        visible: root.openedViaShortcut && root.activeMode !== "idle"
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.activeMode = "idle";
                root.openedViaShortcut = false;
            }
        }
    }

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
                    root.activeMode = "idle";
                    root.openedViaShortcut = false;
                    event.accepted = true;
                } else {
                    root.regainFocus();
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
                    ctx.fillStyle = Theme.colors.bg ?? "#16161e";
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
                    ctx.fillStyle = Theme.colors.bg ?? "#16161e";
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
                color: Theme.colors.bg ?? "#16161e"
                clip: true
                
                radius: 0
                bottomLeftRadius: root.targetRadius
                bottomRightRadius: root.targetRadius

                Behavior on width  { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                // 1. Persistent Dash Layer (Fades in when returning to idle/hover, fades out on expansion)
                Item {
                    id: dashContainer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 30
                    z: 5

                    opacity: root.isDashMode ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                    MainDash { 
                        id: dashMod 
                        anchors.fill: parent
                    }
                }

                // 2. Expanded Modules Container (Fast cross-fade on open/close without layout snapping)
                Item {
                    id: modulesContainer
                    anchors.fill: parent
                    anchors.margins: 12
                    z: 1

                    opacity: (!root.isDashMode && notch.height > 60) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                    StackLayout {
                        id: contentStack
                        anchors.fill: parent

                        currentIndex: {
                            var mode = root.isDashMode ? root.previousExpandedMode : root.activeMode;
                            switch(mode) {
                                case "launcher":   return 0;
                                case "theme":      return 1;
                                case "wallpaper":  return 2;
                                case "transition": return 3;
                                case "osd":        return 4;
                                case "bluetooth":  return 5;
                                case "wifi":       return 6;
                                case "recorder":   return 7;
                                case "battery":    return 8;
                                case "powermenu":  return 9;
                                case "calendar":   return 10;
                                default:           return 0;
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
                    }
                }

                Timer {
                    id: autoCollapseTimer
                    interval: 60
                    repeat: false
                    onTriggered: {
                        if (root.openedViaShortcut) return;
                        if (!notchHoverHandler.hovered && root.activeMode !== "idle" && root.activeMode !== "osd" && !root.isWorkspacePeeking) {
                            root.activeMode = "idle";
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
                            if (!root.openedViaShortcut) {
                                autoCollapseTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }
}
