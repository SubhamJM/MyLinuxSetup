import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth

ShellRoot {
    id: root

    // =========================================================================
    // DYNAMIC THEME ENGINE
    // =========================================================================
    property var themeColors: ({
        "bg": "#16161e",
        "card_bg": "#1f2335",
        "hover_bg": "#24283b",
        "border": "#16161e",
        "border_hover": "#7aa2f7",
        "text_primary": "#c0caf5",
        "text_secondary": "#565f89",
        "accent": "#7aa2f7"
    })

    property string currentThemeName: "default"
    property string activeTransition: "simple"

    function reloadTheme() {
        if (themeLoader.running) themeLoader.running = false;
        themeLoader.running = true;
        
        if (themeNameLoader.running) themeNameLoader.running = false;
        themeNameLoader.running = true;

        if (transitionLoader.running) transitionLoader.running = false;
        transitionLoader.running = true;
    }

    Timer {
        id: themePollTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.reloadTheme()
    }

    Process {
        id: themeLoader
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/quickshell-colors.json"]

        stdout: StdioCollector {
            id: themeCollector
            onStreamFinished: {
                var rawText = themeCollector.text;
                if (!rawText || rawText.trim() === "") return;

                try {
                    var parsed = JSON.parse(rawText);
                    root.themeColors = parsed;
                    leftWing.requestPaint();
                    rightWing.requestPaint();
                } catch(e) {
                    console.warn("[Quickshell Theme] Failed to parse JSON:", e);
                }
            }
        }
    }

    Process {
        id: themeNameLoader
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/theme-name.txt 2>/dev/null || echo 'default'"]

        stdout: StdioCollector {
            onStreamFinished: {
                var name = this.text.trim();
                if (name !== "") root.currentThemeName = name;
            }
        }
    }

    Process {
        id: transitionLoader
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/wallpaper-transition.txt 2>/dev/null || echo 'simple'"]

        stdout: StdioCollector {
            onStreamFinished: {
                var trans = this.text.trim();
                if (trans !== "") root.activeTransition = trans;
            }
        }
    }

    // =========================================================================
    // MODULAR REGISTRY: Mode Definitions & Dimensions
    // =========================================================================
    readonly property var modeDimensions: ({
        "idle":       { width: 120, height: 30,  radius: 12 },
        "hover":      { width: 560, height: 30,  radius: 12 },
        "launcher":   { width: 460, height: 420, radius: 12 },
        "theme":      { width: 400, height: 250, radius: 12 },
        "wallpaper":  { width: 520, height: 320, radius: 12 },
        "transition": { width: 420, height: 260, radius: 12 },
        "osd":        { width: 280, height: 40,  radius: 16 },
        "wifi":       { width: 400, height: 420, radius: 12 }, 
        "bluetooth":  { width: 400, height: 420, radius: 12 }
    })

    property string activeMode: "idle"

    function switchMode(newMode) {
        if (activeMode === newMode) {
            activeMode = "idle";
        } else {
            activeMode = newMode;
        }
    }

    function regainFocus() {
        if (activeMode === "launcher") searchInput.forceActiveFocus();
        else if (activeMode === "theme") themeList.forceActiveFocus();
        else if (activeMode === "wallpaper") wallpaperGrid.forceActiveFocus();
        else if (activeMode === "transition") transitionGrid.forceActiveFocus();
    }

    onActiveModeChanged: {
        if (activeMode === "wifi") {
            wifiStatusChecker.running = true;
            wifiScanner.running = true;
        } else if (activeMode === "bluetooth" && typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = true;
        } else if (typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = false;
        }

        Qt.callLater(() => {
            root.regainFocus();
            if (activeMode !== "launcher") {
                searchInput.text = "";
            }
        });
    }

    readonly property int targetWidth:  modeDimensions[activeMode]?.width  ?? modeDimensions["idle"].width
    
    readonly property int targetHeight: {
        if (activeMode === "launcher") {
            var calculatedHeight = 66 + (filteredAppModel.count * 48);
            return Math.min(420, Math.max(100, calculatedHeight));
        }
        return modeDimensions[activeMode]?.height ?? modeDimensions["idle"].height;
    }
    
    readonly property int targetRadius: modeDimensions[activeMode]?.radius ?? modeDimensions["idle"].radius
    readonly property int cornerCurveRadius: 12

    // =========================================================================
    // OSD STATE ENGINE & NATIVE PROCESS LISTENERS
    // =========================================================================
    property string osdType: "volume"
    property int osdValue: 50
    property bool osdReady: false

    function triggerOsd(type, val) {
        var clampedVal = Math.max(0, Math.min(100, val));
        
        root.osdType = type;
        root.osdValue = clampedVal;

        if (root.activeMode !== "osd") {
            root.osdReady = false;
            root.activeMode = "osd";
            osdSettleTimer.restart();
        } else {
            root.osdReady = true;
        }
        
        osdHideTimer.restart();
    }

    Timer {
        id: osdSettleTimer
        interval: 150
        onTriggered: root.osdReady = true
    }

    Timer {
        id: osdHideTimer
        interval: 2000
        onTriggered: {
            if (root.activeMode === "osd") {
                root.activeMode = "idle";
                root.osdReady = false;
            }
        }
    }

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
                        var type = parts[0];
                        var val = parseInt(parts[1]);
                        if (!isNaN(val)) {
                            root.triggerOsd(type, val);
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: osdPollTimer
        interval: 50
        running: true
        repeat: true
        property string lastEvent: ""

        onTriggered: {
            if (!osdFileReader.running) {
                osdFileReader.running = true;
            }
        }
    }

    GlobalShortcut {
        name: "toggleNotchLauncher"
        onPressed: root.switchMode("launcher")
    }

    GlobalShortcut {
        name: "toggleThemeNotch"
        onPressed: root.switchMode("theme")
    }

    GlobalShortcut {
        name: "toggleWallpaperNotch"
        onPressed: root.switchMode("wallpaper")
    }

    GlobalShortcut {
        name: "toggleTransitionNotch"
        onPressed: root.switchMode("transition")
    }

    GlobalShortcut {
        name: "resetNotchToIdle"
        onPressed: root.activeMode = "idle"
    }

    // =========================================================================
    // DATA MODELS & STATE MANAGERS
    // =========================================================================
    property var allApps: []
    property var allThemes: []
    property var allWallpapers: []
    property var allTransitions: ["simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "outer", "random"]

    ListModel { id: filteredAppModel }
    ListModel { id: themeModel }
    ListModel { id: wallpaperModel }
    ListModel { id: transitionModel }
    ListModel { id: wifiModel }

    Component.onCompleted: {
        updateTransitionList();
    }

    function isSubsequence(query, target) {
        var qLen = query.length, tLen = target.length;
        if (qLen > tLen) return false;
        var qIdx = 0, tIdx = 0;
        while (qIdx < qLen && tIdx < tLen) {
            if (query[qIdx] === target[tIdx]) qIdx++;
            tIdx++;
        }
        return qIdx === qLen;
    }

    function updateAppList(filterText) {
        filteredAppModel.clear();
        var query = filterText.toLowerCase().trim();
        for (var i = 0; i < allApps.length; i++) {
            var app = allApps[i];
            if (query === "" || isSubsequence(query, app.name.toLowerCase())) {
                filteredAppModel.append(app);
            }
        }
    }

    function updateThemeList() {
        themeModel.clear();
        for (var i = 0; i < allThemes.length; i++) {
            themeModel.append({"themeName": allThemes[i]});
        }
    }

    function updateWallpaperList() {
        wallpaperModel.clear();
        for (var i = 0; i < allWallpapers.length; i++) {
            wallpaperModel.append(allWallpapers[i]);
        }
    }

    function updateTransitionList() {
        transitionModel.clear();
        for (var i = 0; i < allTransitions.length; i++) {
            transitionModel.append({"transitionName": allTransitions[i]});
        }
    }

    // =========================================================================
    // BACKGROUND PROCESSES
    // =========================================================================
    Process {
        id: appScanner
        running: root.activeMode === "launcher"
        command: ["sh", "-c", `
            python3 -c "
import os, glob, re
apps = []
paths = ['/usr/share/applications', os.path.expanduser('~/.local/share/applications')]
for p in paths:
    for f in glob.glob(p + '/*.desktop'):
        try:
            with open(f, 'r', encoding='utf-8', errors='ignore') as file:
                content = file.read()
                if 'NoDisplay=true' in content: continue
                name = re.search(r'^Name=(.*)$', content, re.M)
                exec_cmd = re.search(r'^Exec=(.*)$', content, re.M)
                icon = re.search(r'^Icon=(.*)$', content, re.M)
                comment = re.search(r'^Comment=(.*)$', content, re.M)
                if name and exec_cmd and icon and icon.group(1).strip():
                    n = name.group(1).strip()
                    e = re.sub(r'%[fFuUiDc]', '', exec_cmd.group(1)).strip()
                    i = icon.group(1).strip()
                    c = comment.group(1).strip() if comment else ''
                    apps.append(f'{n}|||{e}|||{i}|||{c}')
        except: pass
print('\\n'.join(sorted(set(apps))))
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var tempList = [];
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 3) {
                        tempList.push({
                            "name": parts[0],
                            "exec": parts[1],
                            "iconName": parts[2],
                            "comment": parts.length > 3 ? parts[3] : ""
                        });
                    }
                }
                root.allApps = tempList;
                root.updateAppList(searchInput.text);
            }
        }
    }

    Process {
        id: themeScanner
        running: root.activeMode === "theme"
        command: ["sh", "-c", `python3 -c "import os; d=os.path.expanduser('~/.config/themes'); print('\\n'.join(sorted(os.listdir(d))) if os.path.exists(d) else '')"`]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var tempList = [];
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim() !== "") tempList.push(lines[i].trim());
                }
                root.allThemes = tempList;
                root.updateThemeList();
            }
        }
    }

    Process {
        id: wallpaperScanner
        running: root.activeMode === "wallpaper"
        command: ["sh", "-c", `python3 -c "
import os, glob
theme = '${root.currentThemeName}'
wall_dir = os.path.expanduser(f'~/Pictures/Wallpapers/{theme}')
exts = ('*.jpg', '*.jpeg', '*.png', '*.webp')
files = []
if os.path.exists(wall_dir):
    for ext in exts:
        files.extend(glob.glob(os.path.join(wall_dir, ext)))
    files.extend(glob.glob(os.path.join(wall_dir, '*/*.jpg')))
    files.extend(glob.glob(os.path.join(wall_dir, '*/*.png')))
for f in sorted(list(set(files))):
    name = os.path.basename(f)
    print(f'{name}|||{f}')
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var tempList = [];
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 2) {
                        tempList.push({
                            "fileName": parts[0],
                            "filePath": parts[1]
                        });
                    }
                }
                root.allWallpapers = tempList;
                root.updateWallpaperList();
            }
        }
    }

    Process { id: appRunner; running: false }
    Process { id: wallpaperRunner; running: false }
    Process { 
        id: transitionWriter
        running: false
        onExited: root.reloadTheme()
    }

    Process { 
        id: themeRunner
        running: false
        onExited: {
            root.reloadTheme();
        }
    }

    Process {
        id: wifiScanner
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                wifiModel.clear();
                var lines = this.text.trim().split("\n");
                var seen = {};
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":");
                    if (parts.length >= 4 && parts[1] !== "") {
                        var ssid = parts[1];
                        if (!seen[ssid]) {
                            seen[ssid] = true;
                            wifiModel.append({
                                "inUse": parts[0] === "*",
                                "ssid": ssid,
                                "signal": parseInt(parts[2]),
                                "security": parts[3]
                            });
                        }
                    }
                }
            }
        }
    }

    Process { id: wifiConnector; running: false }
    Process { id: hotspotRunner; running: false }

    property bool wifiEnabled: true

    Process {
        id: wifiStatusChecker
        command: ["sh", "-c", "nmcli radio wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = (this.text.trim() === "enabled");
            }
        }
    }

    Process {
        id: wifiToggler
        running: false
        onExited: {
            wifiStatusChecker.running = true;
            wifiScanner.running = true;
        }
    }

    // =========================================================================
    // MAIN PANEL & NOTCH WINDOW
    // =========================================================================
    PanelWindow {
        id: panel
        anchors.top: true
        implicitWidth: 600
        implicitHeight: root.targetHeight + 60
        exclusiveZone: 30
        color: "transparent"

        WlrLayershell.keyboardFocus: (root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "osd") 
            ? WlrKeyboardFocus.Exclusive 
            : WlrKeyboardFocus.None

        // OUTSIDE CLICK DISMISSAL AREA (Spans full panel surface)
        MouseArea {
            anchors.fill: parent
            enabled: root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "osd"
            onClicked: root.activeMode = "idle"
        }

        Item {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: notch.width
            height: notch.height
            
            focus: root.activeMode !== "idle" && root.activeMode !== "hover"
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.activeMode = "idle";
                    event.accepted = true;
                } else {
                    root.regainFocus();
                }
            }

            // LEFT WING
            Canvas {
                id: leftWing
                width: root.cornerCurveRadius
                height: root.cornerCurveRadius
                anchors.top: parent.top
                anchors.right: notch.left
                anchors.rightMargin: -1 

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = root.themeColors.bg ?? "#16161e";
                    ctx.beginPath();
                    ctx.moveTo(width + 1, 0);
                    ctx.lineTo(width + 1, height);
                    ctx.arcTo(width, 0, 0, 0, height);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            // RIGHT WING
            Canvas {
                id: rightWing
                width: root.cornerCurveRadius
                height: root.cornerCurveRadius
                anchors.top: parent.top
                anchors.left: notch.right
                anchors.leftMargin: -1 

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = root.themeColors.bg ?? "#16161e";
                    ctx.beginPath();
                    ctx.moveTo(-1, 0);
                    ctx.lineTo(-1, height);
                    ctx.arcTo(0, 0, width, 0, height);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            // MAIN NOTCH BODY
            Rectangle {
                id: notch
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter

                width: root.targetWidth
                height: root.targetHeight
                color: root.themeColors.bg ?? "#16161e"
                
                radius: 0
                bottomLeftRadius: root.targetRadius
                bottomRightRadius: root.targetRadius

                Behavior on width  { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                // Block click events inside the notch from leaking to the backdrop dismissal MouseArea
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: (mouse) => mouse.accepted = true
                }

                // =============================================================
                // MODULAR CONTENT STACK
                // =============================================================
                StackLayout {
                    id: contentStack
                    anchors.fill: parent
                    anchors.margins: root.activeMode === "idle" || root.activeMode === "hover" ? 0 : 12

                    currentIndex: {
                        switch(root.activeMode) {
                            case "idle":       return 0;
                            case "hover":      return 0;
                            case "launcher":   return 1;
                            case "theme":      return 2;
                            case "wallpaper":  return 3;
                            case "transition": return 4;
                            case "osd":        return 5;
                            case "bluetooth":  return 6;
                            case "wifi":       return 7;
                            default:           return 0;
                        }
                    }

                    // MODULE 0: Main Dash (Idle & Hover)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0

                            // LEFT: Workspaces
                            Row {
                                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                                spacing: 6
                                visible: root.activeMode === "hover"
                                opacity: visible ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }

                                Repeater {
                                    model: typeof Hyprland !== "undefined" ? Hyprland.workspaces : []
                                    delegate: Rectangle {
                                        width: 26; height: 26; radius: 8
                                        property bool isFocused: modelData.id === (typeof Hyprland !== "undefined" ? Hyprland.focusedWorkspace.id : -1)
                                        color: isFocused ? (root.themeColors.accent ?? "#7aa2f7") : (workspaceMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : "transparent")
                                        border.width: workspaceMouse.containsMouse && !isFocused ? 1 : 0
                                        border.color: root.themeColors.border_hover ?? "#7aa2f7"
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.id
                                            color: parent.isFocused ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_primary ?? "white")
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                        MouseArea {
                                            id: workspaceMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: modelData.focus()
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true; visible: root.activeMode === "hover" }

                            // CENTER: Date & Time
                            Rectangle {
                                Layout.alignment: Qt.AlignCenter
                                width: timeRow.implicitWidth + 24
                                height: 26
                                radius: 8
                                color: timeMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : "transparent"
                                border.width: timeMouse.containsMouse ? 1 : 0
                                border.color: root.themeColors.border_hover ?? "#7aa2f7"
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Row {
                                    id: timeRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        text: Qt.formatDateTime(clock.date, "ddd d MMM")
                                        color: root.themeColors.text_secondary ?? "#565f89"
                                        font.pixelSize: 13
                                        font.bold: true
                                        visible: root.activeMode === "hover"
                                    }
                                    Text {
                                        id: clockText
                                        text: Qt.formatDateTime(clock.date, root.activeMode === "hover" ? "hh:mm AP" : "hh:mm")
                                        color: root.themeColors.text_primary ?? "white"
                                        font.pixelSize: 14
                                        font.bold: true
                                        renderType: Text.QtRendering
                                    }
                                }
                                MouseArea {
                                    id: timeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }

                            Item { Layout.fillWidth: true; visible: root.activeMode === "hover" }

                            // RIGHT: System Tray & Power Options
                            Row {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                spacing: 6
                                visible: root.activeMode === "hover"
                                opacity: visible ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }

                                // Wi-Fi Button
                                Rectangle {
                                    width: 26; height: 26; radius: 8
                                    color: wifiMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : "transparent"
                                    border.width: wifiMouse.containsMouse ? 1 : 0
                                    border.color: root.themeColors.border_hover ?? "#7aa2f7"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰖩"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                                        color: root.themeColors.text_primary ?? "#c0caf5"
                                    }
                                    MouseArea {
                                        id: wifiMouse
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.switchMode("wifi")
                                    }
                                }

                                // Bluetooth Button
                                Rectangle {
                                    width: 26; height: 26; radius: 8
                                    color: btMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : "transparent"
                                    border.width: btMouse.containsMouse ? 1 : 0
                                    border.color: root.themeColors.border_hover ?? "#7aa2f7"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰂯"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                                        color: root.themeColors.text_primary ?? "#c0caf5"
                                    }
                                    MouseArea {
                                        id: btMouse
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.switchMode("bluetooth")
                                    }
                                }

                                // Battery Button
                                Rectangle {
                                    width: battRow.implicitWidth + 16; height: 26; radius: 8
                                    color: battMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : "transparent"
                                    border.width: battMouse.containsMouse ? 1 : 0
                                    border.color: root.themeColors.border_hover ?? "#7aa2f7"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Row {
                                        id: battRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        property int batteryLevel: 100
                                        property bool isCharging: false

                                        Timer {
                                            interval: 5000; running: root.activeMode === "hover"; repeat: true; triggeredOnStart: true
                                            onTriggered: {
                                                var xhrCap = new XMLHttpRequest();
                                                xhrCap.open("GET", "file:///sys/class/power_supply/BAT1/capacity", true);
                                                xhrCap.onreadystatechange = function() { if (xhrCap.readyState === XMLHttpRequest.DONE) { var val = parseInt(xhrCap.responseText); if (!isNaN(val)) parent.batteryLevel = val; } }
                                                xhrCap.send();

                                                var xhrStat = new XMLHttpRequest();
                                                xhrStat.open("GET", "file:///sys/class/power_supply/BAT1/status", true);
                                                xhrStat.onreadystatechange = function() { if (xhrStat.readyState === XMLHttpRequest.DONE) { parent.isCharging = (xhrStat.responseText.trim() === "Charging"); } }
                                                xhrStat.send();
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: parent.isCharging ? "󰂄" : (parent.batteryLevel > 20 ? "󰁹" : "󰂃")
                                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                                            color: parent.isCharging || parent.batteryLevel > 20 ? (root.themeColors.accent ?? "#7aa2f7") : "#f44336"
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: parent.batteryLevel + "%"
                                            color: root.themeColors.text_primary ?? "white"
                                            font.pixelSize: 12; font.bold: true; font.features: { "tnum": 1 }
                                        }
                                    }
                                    MouseArea { id: battMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                                }

                                Item {
                                    width: 12; height: 26
                                    Rectangle { anchors.centerIn: parent; width: 1; height: 14; color: root.themeColors.text_secondary ?? "#565f89"; opacity: 0.4 }
                                }

                                // Power Options
                                Rectangle {
                                    width: 26; height: 26; radius: 8
                                    color: suspendMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : "transparent"
                                    border.width: suspendMouse.containsMouse ? 1 : 0
                                    border.color: root.themeColors.border_hover ?? "#7aa2f7"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: "󰒲"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: suspendMouse.containsMouse ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_secondary ?? "#565f89") }
                                    MouseArea { id: suspendMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["systemctl", "suspend"]) }
                                }

                                Rectangle {
                                    width: 26; height: 26; radius: 8
                                    color: rebootMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : "transparent"
                                    border.width: rebootMouse.containsMouse ? 1 : 0
                                    border.color: root.themeColors.border_hover ?? "#7aa2f7"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: "󰜉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: rebootMouse.containsMouse ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_secondary ?? "#565f89") }
                                    MouseArea { id: rebootMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["systemctl", "reboot"]) }
                                }

                                Rectangle {
                                    width: 26; height: 26; radius: 8
                                    color: shutdownMouse.containsMouse ? "#f44336" : "transparent"
                                    border.width: shutdownMouse.containsMouse ? 1 : 0
                                    border.color: "#f44336"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: "󰐥"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: shutdownMouse.containsMouse ? "white" : (root.themeColors.text_secondary ?? "#565f89") }
                                    MouseArea { id: shutdownMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["systemctl", "poweroff"]) }
                                }
                            }
                        }
                    }

                    // MODULE 1: Launcher
                    ColumnLayout {
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 15

                            Text {
                                text: "⌕"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                color: root.themeColors.text_secondary ?? "#a9b1d6"
                            }

                            TextField {
                                id: searchInput
                                focus: true
                                Layout.fillWidth: true
                                color: root.themeColors.text_primary ?? "#c0caf5"
                                font.pixelSize: 15
                                placeholderText: "Search..."
                                placeholderTextColor: root.themeColors.text_secondary ?? "#565f89"
                                background: Item {}

                                onTextChanged: root.updateAppList(text)

                                Keys.onDownPressed: if (appList.currentIndex < filteredAppModel.count - 1) appList.currentIndex++
                                Keys.onUpPressed:   if (appList.currentIndex > 0) appList.currentIndex--
                                Keys.onEscapePressed: root.activeMode = "idle"

                                onAccepted: {
                                    if (filteredAppModel.count > 0 && appList.currentIndex >= 0) {
                                        var execCmd = filteredAppModel.get(appList.currentIndex).exec;
                                        appRunner.command = ["sh", "-c", execCmd + " &"];
                                        appRunner.running = true;
                                    } else if (text.trim() !== "") {
                                        appRunner.command = ["sh", "-c", text.trim() + " &"];
                                        appRunner.running = true;
                                    }
                                    root.activeMode = "idle";
                                }
                            }
                        }

                        ListView {
                            id: appList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: filteredAppModel
                            currentIndex: 0

                            delegate: Rectangle {
                                width: ListView.view.width
                                height: comment !== "" ? 50 : 38
                                
                                property bool isSelected: ListView.isCurrentItem
                                property string appName: name
                                property string appExec: exec
                                
                                color: isSelected ? (root.themeColors.hover_bg ?? "#24283b") : (appMouse.containsMouse ? (root.themeColors.card_bg ?? "#1f2335") : "transparent")
                                radius: 8

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 10
                                    anchors.topMargin: 4;  anchors.bottomMargin: 4
                                    spacing: 12

                                    Item {
                                        Layout.preferredWidth: 26
                                        Layout.preferredHeight: 26
                                        Layout.alignment: Qt.AlignVCenter

                                        Image {
                                            id: primaryIcon
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            source: {
                                                if (iconName === "") return "";
                                                if (iconName.startsWith("/")) return "file://" + iconName;
                                                return "image://icon/" + iconName;
                                            }

                                            onStatusChanged: {
                                                if (status === Image.Error) {
                                                    for (var i = 0; i < filteredAppModel.count; i++) {
                                                        if (filteredAppModel.get(i).name === appName && filteredAppModel.get(i).exec === appExec) {
                                                            filteredAppModel.remove(i);
                                                            break;
                                                        }
                                                    }
                                                    var tempApps = [];
                                                    for (var j = 0; j < root.allApps.length; j++) {
                                                        if (root.allApps[j].name !== appName || root.allApps[j].exec !== appExec) {
                                                            tempApps.push(root.allApps[j]);
                                                        }
                                                    }
                                                    root.allApps = tempApps;
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: name
                                            color: isSelected ? (root.themeColors.accent ?? "#ffffff") : (root.themeColors.text_primary ?? "#c0caf5")
                                            font.pixelSize: 13
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: comment !== "" ? comment : exec
                                            color: isSelected ? (root.themeColors.text_primary ?? "#a9b1d6") : (root.themeColors.text_secondary ?? "#565f89")
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            visible: text !== ""
                                        }
                                    }
                                }

                                MouseArea {
                                    id: appMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: appList.currentIndex = index
                                    onClicked: {
                                        appRunner.command = ["sh", "-c", appExec + " &"];
                                        appRunner.running = true;
                                        root.activeMode = "idle";
                                    }
                                }
                            }
                        }
                    }

                    // MODULE 2: Theme Selector
                    ColumnLayout {
                        spacing: 12

                        Text {
                            text: "Themes"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeColors.text_primary ?? "white"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        GridView {
                            id: themeList
                            focus: true
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            cellWidth: width / 2
                            cellHeight: 45
                            model: themeModel

                            Keys.onEscapePressed: root.activeMode = "idle"
                            Keys.onLeftPressed: if (currentIndex > 0) currentIndex--
                            Keys.onRightPressed: if (currentIndex < count - 1) currentIndex++
                            Keys.onUpPressed: if (currentIndex - 2 >= 0) currentIndex -= 2
                            Keys.onDownPressed: if (currentIndex + 2 < count) currentIndex += 2

                            Keys.onReturnPressed: applyTheme(currentIndex)
                            Keys.onEnterPressed: applyTheme(currentIndex)

                            function applyTheme(idx) {
                                if (idx >= 0 && idx < count) {
                                    var name = themeModel.get(idx).themeName;
                                    if (themeRunner.running) themeRunner.running = false;
                                    themeRunner.command = ["sh", "-c", "~/.config/scripts/apply-theme.sh " + name];
                                    themeRunner.running = true;
                                    root.activeMode = "idle";
                                }
                            }

                            delegate: Item {
                                width: GridView.view.cellWidth
                                height: GridView.view.cellHeight

                                property bool isSelected: GridView.isCurrentItem

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    color: isSelected ? (root.themeColors.hover_bg ?? "#24283b") : (themeMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : (root.themeColors.card_bg ?? "#1f2335"))
                                    border.color: isSelected ? (root.themeColors.accent ?? "#7aa2f7") : (themeMouse.containsMouse ? (root.themeColors.border_hover ?? "#7aa2f7") : (root.themeColors.border ?? "#16161e"))
                                    border.width: isSelected ? 2 : 1
                                    radius: 8

                                    Text {
                                        anchors.centerIn: parent
                                        text: themeName
                                        color: isSelected || themeMouse.containsMouse ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_primary ?? "white")
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: themeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: themeList.currentIndex = index
                                        onClicked: themeList.applyTheme(index)
                                    }
                                }
                            }
                        }
                    }

                    // MODULE 3: Wallpaper Selector
                    ColumnLayout {
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "Wallpapers (" + root.currentThemeName + ")"
                                font.pixelSize: 15
                                font.bold: true
                                color: root.themeColors.text_primary ?? "white"
                                Layout.alignment: Qt.AlignLeft
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: wallpaperModel.count + " items"
                                font.pixelSize: 12
                                color: root.themeColors.text_secondary ?? "#565f89"
                                Layout.alignment: Qt.AlignRight
                            }
                        }

                        GridView {
                            id: wallpaperGrid
                            focus: true
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            cellWidth: width / 3
                            cellHeight: 120
                            model: wallpaperModel

                            Keys.onEscapePressed: root.activeMode = "idle"
                            Keys.onLeftPressed: if (currentIndex > 0) currentIndex--
                            Keys.onRightPressed: if (currentIndex < count - 1) currentIndex++
                            Keys.onUpPressed: if (currentIndex - 3 >= 0) currentIndex -= 3
                            Keys.onDownPressed: if (currentIndex + 3 < count) currentIndex += 3

                            Keys.onReturnPressed: applyWallpaper(currentIndex)
                            Keys.onEnterPressed: applyWallpaper(currentIndex)

                            function applyWallpaper(idx) {
                                if (idx >= 0 && idx < count) {
                                    var path = wallpaperModel.get(idx).filePath;
                                    if (wallpaperRunner.running) wallpaperRunner.running = false;

                                    wallpaperRunner.command = [
                                        "awww", "img", path, 
                                        "--transition-type", root.activeTransition,
                                        "--transition-fps", "144",
                                        "--transition-step", "240",
                                        "--transition-bezier", "0.25,0.1,0.25,1.0"
                                    ];
                                    wallpaperRunner.running = true;
                                    root.activeMode = "idle";
                                }
                            }

                            delegate: Item {
                                width: GridView.view.cellWidth
                                height: GridView.view.cellHeight

                                property bool isSelected: GridView.isCurrentItem

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    color: isSelected ? (root.themeColors.hover_bg ?? "#24283b") : (wallMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : (root.themeColors.card_bg ?? "#1f2335"))
                                    border.color: isSelected ? (root.themeColors.accent ?? "#7aa2f7") : (wallMouse.containsMouse ? (root.themeColors.border_hover ?? "#7aa2f7") : (root.themeColors.border ?? "#16161e"))
                                    border.width: isSelected ? 2 : 1
                                    radius: 8
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: "file://" + filePath
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                    }

                                    MouseArea {
                                        id: wallMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: wallpaperGrid.currentIndex = index
                                        onClicked: wallpaperGrid.applyWallpaper(index)
                                    }
                                }
                            }
                        }
                    }

                    // MODULE 4: Wallpaper Transition Selector
                    ColumnLayout {
                        spacing: 12

                        Text {
                            text: "Wallpaper Transitions"
                            font.pixelSize: 16
                            font.bold: true
                            color: root.themeColors.text_primary ?? "white"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        GridView {
                            id: transitionGrid
                            focus: true
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            cellWidth: width / 2
                            cellHeight: 45
                            model: transitionModel

                            Keys.onEscapePressed: root.activeMode = "idle"
                            Keys.onLeftPressed: if (currentIndex > 0) currentIndex--
                            Keys.onRightPressed: if (currentIndex < count - 1) currentIndex++
                            Keys.onUpPressed: if (currentIndex - 2 >= 0) currentIndex -= 2
                            Keys.onDownPressed: if (currentIndex + 2 < count) currentIndex += 2

                            Keys.onReturnPressed: applyTransition(currentIndex)
                            Keys.onEnterPressed: applyTransition(currentIndex)

                            function applyTransition(idx) {
                                if (idx >= 0 && idx < count) {
                                    var trans = transitionModel.get(idx).transitionName;
                                    if (transitionWriter.running) transitionWriter.running = false;

                                    transitionWriter.command = [
                                        "sh", "-c", 
                                        "mkdir -p $HOME/.config/active-theme && echo -n '" + trans + "' > $HOME/.config/active-theme/wallpaper-transition.txt"
                                    ];
                                    transitionWriter.running = true;
                                    root.activeMode = "idle";
                                }
                            }

                            delegate: Item {
                                width: GridView.view.cellWidth
                                height: GridView.view.cellHeight

                                property bool isCurrent: transitionName === root.activeTransition
                                property bool isSelected: GridView.isCurrentItem

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    color: isSelected ? (root.themeColors.hover_bg ?? "#24283b") : (transMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : (isCurrent ? (root.themeColors.hover_bg ?? "#24283b") : (root.themeColors.card_bg ?? "#1f2335")))
                                    border.color: isSelected ? (root.themeColors.accent ?? "#7aa2f7") : (isCurrent ? (root.themeColors.accent ?? "#7aa2f7") : (transMouse.containsMouse ? (root.themeColors.border_hover ?? "#7aa2f7") : (root.themeColors.border ?? "#16161e")))
                                    border.width: isSelected || isCurrent ? 2 : 1
                                    radius: 8

                                    Text {
                                        anchors.centerIn: parent
                                        text: transitionName + (isCurrent ? " ✓" : "")
                                        color: isSelected || isCurrent || transMouse.containsMouse ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_primary ?? "white")
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: transMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: transitionGrid.currentIndex = index
                                        onClicked: transitionGrid.applyTransition(index)
                                    }
                                }
                            }
                        }
                    }

                    // MODULE 5: OSD (Volume / Brightness)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 16

                            Text {
                                text: root.osdType === "brightness" ? "󰃠" : (root.osdValue == 0 ? "󰖁" : "󰕾")
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                color: root.themeColors.text_primary ?? "#c0caf5"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Rectangle {
                                id: osdTrack
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                height: 6
                                radius: 3
                                color: root.themeColors.hover_bg ?? "#24283b"
                                clip: true

                                Rectangle {
                                    width: osdTrack.width * (root.osdValue / 100.0)
                                    height: parent.height
                                    radius: 3
                                    color: root.themeColors.accent ?? "#7aa2f7"

                                    Behavior on width {
                                        enabled: root.osdReady
                                        NumberAnimation { 
                                            duration: 120; 
                                            easing.type: Easing.OutCubic 
                                        }
                                    }
                                }
                            }

                            Text {
                                text: root.osdValue + "%"
                                font.pixelSize: 13
                                font.bold: true
                                color: root.themeColors.text_primary ?? "#c0caf5"
                                Layout.alignment: Qt.AlignVCenter
                                Layout.minimumWidth: 35
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                    
                    // MODULE 6: Bluetooth
                    ColumnLayout {
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Bluetooth Devices"
                                font.pixelSize: 16
                                font.bold: true
                                color: root.themeColors.text_primary ?? "white"
                            }
                            Item { Layout.fillWidth: true }
                            
                            Rectangle {
                                width: 80; height: 28; radius: 8
                                color: typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.card_bg ?? "#1f2335")
                                Text {
                                    anchors.centerIn: parent
                                    text: typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? "Scanning..." : "Scan"
                                    color: typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_primary ?? "white")
                                    font.bold: true; font.pixelSize: 12
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
                                            Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering;
                                        }
                                    }
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: typeof Bluetooth !== "undefined" && Bluetooth.devices ? Bluetooth.devices.values : []

                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 45
                                radius: 8
                                color: root.themeColors.card_bg ?? "#1f2335"
                                border.width: 1
                                border.color: root.themeColors.border ?? "#16161e"
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    
                                    Text {
                                        text: modelData.connected ? "󰂱" : "󰂯"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                                        color: modelData.connected ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_secondary ?? "#565f89")
                                    }
                                    
                                    Column {
                                        Layout.fillWidth: true
                                        Text {
                                            text: modelData.name !== "" ? modelData.name : "Unknown Device"
                                            color: root.themeColors.text_primary ?? "white"
                                            font.pixelSize: 13; font.bold: true
                                            elide: Text.ElideRight; width: parent.width
                                        }
                                        Text {
                                            text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                                            color: root.themeColors.text_secondary ?? "#565f89"
                                            font.pixelSize: 11
                                        }
                                    }

                                    Rectangle {
                                        width: 70; height: 26; radius: 6
                                        color: modelData.connected ? "#f44336" : (root.themeColors.hover_bg ?? "#24283b")
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.connected ? "Disconnect" : "Connect"
                                            color: "white"
                                            font.bold: true; font.pixelSize: 11
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.connected) {
                                                    modelData.disconnect();
                                                } else {
                                                    modelData.connect();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // MODULE 7: Wi-Fi
                    ColumnLayout {
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Wi-Fi"
                                font.pixelSize: 16
                                font.bold: true
                                color: root.themeColors.text_primary ?? "white"
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 70; height: 28; radius: 14
                                color: root.wifiEnabled ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.hover_bg ?? "#24283b")
                                border.width: 1
                                border.color: root.themeColors.border_hover ?? "#7aa2f7"

                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                    spacing: 4

                                    Text {
                                        text: root.wifiEnabled ? "ON" : "OFF"
                                        font.bold: true; font.pixelSize: 10
                                        color: root.wifiEnabled ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_secondary ?? "#565f89")
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        color: root.wifiEnabled ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_secondary ?? "#565f89")
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var targetState = root.wifiEnabled ? "off" : "on";
                                        root.wifiEnabled = !root.wifiEnabled;
                                        wifiToggler.command = ["sh", "-c", "nmcli radio wifi " + targetState];
                                        wifiToggler.running = true;
                                    }
                                }
                            }

                            Rectangle {
                                width: 95; height: 28; radius: 8
                                color: hotspotRunner.running ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.card_bg ?? "#1f2335")
                                Text {
                                    anchors.centerIn: parent
                                    text: hotspotRunner.running ? "Hotspot On" : "Hotspot"
                                    color: hotspotRunner.running ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_primary ?? "white")
                                    font.bold: true; font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!hotspotRunner.running) {
                                            hotspotRunner.command = ["sh", "-c", "nmcli device wifi hotspot ssid 'Arch-Hotspot' password 'secret123'"];
                                            hotspotRunner.running = true;
                                        } else {
                                            Quickshell.execDetached(["nmcli", "connection", "down", "Hotspot"]);
                                            hotspotRunner.running = false;
                                        }
                                    }
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: root.wifiEnabled ? wifiModel : []

                            Item {
                                anchors.fill: parent
                                visible: !root.wifiEnabled
                                Text {
                                    anchors.centerIn: parent
                                    text: "Wi-Fi is disabled"
                                    color: root.themeColors.text_secondary ?? "#565f89"
                                    font.pixelSize: 13
                                }
                            }

                            delegate: Rectangle {
                                width: ListView.view.width
                                height: wifiMouse.expanded ? 80 : 45
                                radius: 8
                                color: root.themeColors.card_bg ?? "#1f2335"
                                border.width: 1
                                border.color: root.themeColors.border ?? "#16161e"
                                clip: true
                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }
                                
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    
                                    RowLayout {
                                        width: parent.width
                                        spacing: 10
                                        
                                        Text {
                                            text: inUse ? "󰖩" : "󰖪"
                                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                                            color: inUse ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_secondary ?? "#565f89")
                                        }
                                        
                                        Column {
                                            Layout.fillWidth: true
                                            Text {
                                                text: ssid
                                                color: inUse ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_primary ?? "white")
                                                font.pixelSize: 13; font.bold: true
                                                elide: Text.ElideRight; width: parent.width
                                            }
                                            Text {
                                                text: (security !== "" && security !== "--" ? "Secured" : "Open") + " • " + signal + "%"
                                                color: root.themeColors.text_secondary ?? "#565f89"
                                                font.pixelSize: 11
                                            }
                                        }

                                        Text {
                                            text: inUse ? "Connected" : (wifiMouse.expanded ? "Cancel" : "Connect")
                                            color: inUse ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_primary ?? "white")
                                            font.bold: true; font.pixelSize: 12
                                        }
                                    }

                                    RowLayout {
                                        width: parent.width
                                        visible: wifiMouse.expanded
                                        opacity: wifiMouse.expanded ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                        
                                        TextField {
                                            id: passField
                                            Layout.fillWidth: true
                                            placeholderText: "Password..."
                                            echoMode: TextInput.Password
                                            color: root.themeColors.text_primary ?? "white"
                                            background: Rectangle {
                                                color: root.themeColors.bg ?? "#16161e"
                                                radius: 4
                                            }
                                        }
                                        
                                        Rectangle {
                                            width: 60; height: 26; radius: 6
                                            color: root.themeColors.accent ?? "#7aa2f7"
                                            Text { anchors.centerIn: parent; text: "Go"; color: root.themeColors.bg ?? "#16161e"; font.bold: true; font.pixelSize: 11 }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    wifiConnector.command = ["sh", "-c", "nmcli dev wifi connect '" + ssid + "' password '" + passField.text + "'"];
                                                    wifiConnector.running = true;
                                                    wifiScanner.running = true;
                                                    root.switchMode("idle");
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: wifiMouse
                                    property bool expanded: false
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (inUse) return;
                                        expanded = !expanded;
                                    }
                                }
                            }
                        }
                    }

                }

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    enabled: root.activeMode === "idle" || root.activeMode === "hover"
                    
                    onEntered: {
                        if (root.activeMode === "idle") {
                            root.activeMode = "hover";
                        }
                    }
                    
                    onExited: {
                        if (root.activeMode === "hover") {
                            root.activeMode = "idle";
                        }
                    }
                }
            }
        }
    }
}
