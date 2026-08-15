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
        "wifi":       { width: 420, height: 420, radius: 12 }, 
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
            root.networkActiveTab = "wifi";
            wifiStatusChecker.running = true;
            wifiSavedChecker.running = true;
            hotspotStatusChecker.running = true;
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
    
    // Dynamic height calculation engine
    readonly property int targetHeight: {
        if (activeMode === "launcher") {
            var calculatedHeight = 66 + (filteredAppModel.count * 48);
            return Math.min(420, Math.max(100, calculatedHeight));
        }
        if (activeMode === "wifi") {
            if (root.networkActiveTab === "hotspot") {
                return 320; // Clean fixed height for Hotspot config view
            }
            if (!root.wifiEnabled) {
                return 180; // Disabled state height
            }
            // Base chrome: container padding (24) + tab selector (32) + spacing (10) + header row (26) + spacing (8) + margin (6)
            var baseChromeHeight = 106;
            var listItemsHeight = 0;
            var count = wifiModel.count;
            
            if (count === 0) {
                return 180; // Empty / scanning height
            }

            for (var i = 0; i < count; i++) {
                var item = wifiModel.get(i);
                var cardH = 48;
                if (item.inUse) {
                    cardH = 50;
                } else if (item.isExpanded) {
                    cardH = item.showPassword ? 116 : 84;
                }
                listItemsHeight += (cardH + 6); // card height + list spacing
            }

            var totalWifiHeight = baseChromeHeight + listItemsHeight;
            return Math.min(440, Math.max(160, totalWifiHeight));
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
    // BACKGROUND PROCESSES: APPS, THEMES, WALLPAPERS
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

    // =========================================================================
    // WI-FI & HOTSPOT STATE ENGINE
    // =========================================================================
    property string networkActiveTab: "wifi" // "wifi" | "hotspot"
    property bool wifiEnabled: true
    property bool hotspotActive: false
    property string activeWifiSsid: ""
    property bool isWifiScanning: false
    property var savedConnections: ({})

    // Configurable Hotspot State
    property string hotspotSsid: "SubhamLaptop"
    property string hotspotPass: "000000001"
    property bool hotspotShowPassword: false

    function isAnyWifiExpanded() {
        for (var i = 0; i < wifiModel.count; i++) {
            if (wifiModel.get(i).isExpanded) return true;
        }
        return false;
    }

    Process {
        id: wifiSavedChecker
        command: ["sh", "-c", "nmcli -t -f TYPE,NAME con show | grep -E '^802-11-wireless:|^wifi:' | cut -d: -f2-"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var map = {};
                for (var i = 0; i < lines.length; i++) {
                    var name = lines[i].trim();
                    if (name !== "") map[name] = true;
                }
                root.savedConnections = map;
                wifiScanner.running = true;
            }
        }
    }

    Process {
        id: wifiScanner
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var stateMap = {};
                for (var k = 0; k < wifiModel.count; k++) {
                    var item = wifiModel.get(k);
                    if (item.isExpanded) {
                        stateMap[item.ssid] = {
                            "isExpanded": item.isExpanded,
                            "showPassword": item.showPassword
                        };
                    }
                }

                wifiModel.clear();
                var lines = this.text.trim().split("\n");
                var seen = {};
                var foundActiveSsid = "";
                
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":");
                    if (parts.length >= 4 && parts[1] !== "") {
                        var isConnected = parts[0] === "*";
                        var ssid = parts[1];
                        if (isConnected) foundActiveSsid = ssid;

                        if (!seen[ssid]) {
                            seen[ssid] = true;
                            
                            var prev = stateMap[ssid];
                            var wasExpanded = prev ? prev.isExpanded : false;
                            var wasShowingPass = prev ? prev.showPassword : false;
                            var hasSavedProfile = !!root.savedConnections[ssid];

                            wifiModel.append({
                                "inUse": isConnected,
                                "ssid": ssid,
                                "signal": parseInt(parts[2]),
                                "security": parts[3],
                                "isSaved": hasSavedProfile,
                                "isExpanded": wasExpanded,
                                "showPassword": wasShowingPass
                            });
                        }
                    }
                }
                root.activeWifiSsid = foundActiveSsid;
                root.isWifiScanning = false;
            }
        }
    }

    Process {
        id: wifiRescanTrigger
        running: false
        command: ["sh", "-c", "nmcli dev wifi rescan"]
        onExited: {
            wifiSavedChecker.running = true;
        }
    }

    function triggerWifiScan() {
        root.isWifiScanning = true;
        wifiRescanTrigger.running = true;
    }

    Process { 
        id: wifiConnector
        running: false
        onExited: wifiSavedChecker.running = true
    }

    Process {
        id: wifiDisconnecter
        running: false
        onExited: wifiSavedChecker.running = true
    }

    Process {
        id: wifiForgetRunner
        running: false
        onExited: wifiSavedChecker.running = true
    }

    Process {
        id: wifiTrustRunner
        running: false
        onExited: wifiSavedChecker.running = true
    }

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
            wifiSavedChecker.running = true;
        }
    }

    Process {
        id: hotspotStatusChecker
        command: ["sh", "-c", "nmcli -t -f TYPE,NAME con show --active | grep -E '^802-11-wireless.*:Hotspot|^wifi.*:Hotspot' || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hotspotActive = this.text.trim().length > 0;
            }
        }
    }

    Process {
        id: hotspotRunner
        running: false
        onExited: {
            hotspotStatusChecker.running = true;
            wifiStatusChecker.running = true;
            wifiSavedChecker.running = true;
        }
    }

    function toggleHotspot(enable) {
        if (enable) {
            var safeSsid = root.hotspotSsid.replace(/'/g, "'\\''");
            var safePass = root.hotspotPass.replace(/'/g, "'\\''");
            var cmd = "nmcli radio wifi on && sleep 0.5 && nmcli device wifi hotspot ssid '" + safeSsid + "' password '" + safePass + "'";
            hotspotRunner.command = ["sh", "-c", cmd];
            hotspotRunner.running = true;
        } else {
            hotspotRunner.command = [
                "sh", "-c", 
                "nmcli connection down Hotspot || nmcli connection down id '" + root.hotspotSsid.replace(/'/g, "'\\''") + "' || true"
            ];
            hotspotRunner.running = true;
        }
    }

    Timer {
        id: wifiPeriodicPoll
        interval: 4000
        running: root.activeMode === "wifi"
        repeat: true
        onTriggered: {
            if (!root.isWifiScanning && !root.isAnyWifiExpanded()) {
                wifiSavedChecker.running = true;
            }
            hotspotStatusChecker.running = true;
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
                                    color: wifiModeMouse.containsMouse ? (root.themeColors.hover_bg ?? "#24283b") : "transparent"
                                    border.width: wifiModeMouse.containsMouse ? 1 : 0
                                    border.color: root.themeColors.border_hover ?? "#7aa2f7"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰖩"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                                        color: root.themeColors.text_primary ?? "#c0caf5"
                                    }
                                    MouseArea {
                                        id: wifiModeMouse
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

                    // MODULE 7: Wi-Fi & Hotspot Master Tabbed Module
                    ColumnLayout {
                        spacing: 10

                        // Global Segment / Pill Tab Selector
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 8
                                color: root.themeColors.card_bg ?? "#1f2335"
                                border.width: 1
                                border.color: root.themeColors.border ?? "#16161e"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    spacing: 4

                                    // Tab 1: Wi-Fi Networks
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 6
                                        color: root.networkActiveTab === "wifi" ? (root.themeColors.accent ?? "#7aa2f7") : "transparent"
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Text {
                                                text: "󰖩"
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                                color: root.networkActiveTab === "wifi" ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_secondary ?? "#565f89")
                                            }
                                            Text {
                                                text: "Wi-Fi"
                                                font.bold: true; font.pixelSize: 12
                                                color: root.networkActiveTab === "wifi" ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_primary ?? "white")
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.networkActiveTab = "wifi"
                                        }
                                    }

                                    // Tab 2: Hotspot Setup & Toggle
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 6
                                        color: root.networkActiveTab === "hotspot" ? (root.themeColors.accent ?? "#7aa2f7") : "transparent"
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Text {
                                                text: "󰖪"
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                                color: root.networkActiveTab === "hotspot" ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_secondary ?? "#565f89")
                                            }
                                            Text {
                                                text: root.hotspotActive ? "Hotspot (ON)" : "Hotspot"
                                                font.bold: true; font.pixelSize: 12
                                                color: root.networkActiveTab === "hotspot" ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_primary ?? "white")
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.networkActiveTab = "hotspot"
                                        }
                                    }
                                }
                            }
                        }

                        // SUB-VIEW 1: WI-FI NETWORKS VIEW
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.networkActiveTab === "wifi"
                            spacing: 8

                            // Header sub-bar: Scan & Toggle switch
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Available Networks"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: root.themeColors.text_primary ?? "white"
                                }

                                Item { Layout.fillWidth: true }

                                // Scan Button
                                Rectangle {
                                    width: 64; height: 26; radius: 6
                                    color: root.isWifiScanning ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.card_bg ?? "#1f2335")
                                    border.width: 1
                                    border.color: root.isWifiScanning ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.border ?? "#16161e")

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isWifiScanning ? "Scanning..." : "Scan"
                                        color: root.isWifiScanning ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_primary ?? "white")
                                        font.bold: true; font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!root.isWifiScanning) root.triggerWifiScan();
                                        }
                                    }
                                }

                                // Radio ON/OFF Toggle
                                Rectangle {
                                    width: 60; height: 26; radius: 13
                                    color: root.wifiEnabled ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.hover_bg ?? "#24283b")
                                    border.width: 1
                                    border.color: root.themeColors.border_hover ?? "#7aa2f7"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6; anchors.rightMargin: 6
                                        spacing: 4

                                        Text {
                                            text: root.wifiEnabled ? "ON" : "OFF"
                                            font.bold: true; font.pixelSize: 10
                                            color: root.wifiEnabled ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_secondary ?? "#565f89")
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            width: 16; height: 16; radius: 8
                                            color: root.wifiEnabled ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_secondary ?? "#565f89")
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var targetState = root.wifiEnabled ? "off" : "on";
                                            root.wifiEnabled = !root.wifiEnabled;
                                            wifiToggler.command = ["sh", "-c", "nmcli radio wifi " + targetState];
                                            wifiToggler.running = true;
                                        }
                                    }
                                }
                            }

                            // Wi-Fi ListView
                            ListView {
                                id: wifiListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 6
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
                                    id: wifiCard
                                    width: ListView.view.width
                                    height: inUse ? 50 : (isExpanded ? (showPassword ? 116 : 84) : 48)
                                    radius: 8
                                    color: root.themeColors.card_bg ?? "#1f2335"
                                    border.width: 1
                                    border.color: inUse ? (root.themeColors.accent ?? "#7aa2f7") : (isExpanded ? (root.themeColors.border_hover ?? "#7aa2f7") : (root.themeColors.border ?? "#16161e"))
                                    clip: true

                                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        // Network Header Row
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Text {
                                                text: inUse ? "󰖩" : (signal > 75 ? "󰤨" : (signal > 50 ? "󰤥" : (signal > 25 ? "󰤢" : "󰤟")))
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                                                color: inUse ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_secondary ?? "#565f89")
                                            }

                                            Column {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                RowLayout {
                                                    spacing: 6
                                                    Text {
                                                        text: ssid
                                                        color: inUse ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_primary ?? "white")
                                                        font.pixelSize: 13; font.bold: true
                                                        elide: Text.ElideRight
                                                        Layout.maximumWidth: wifiCard.width - 150
                                                    }
                                                    Text {
                                                        visible: !inUse && isSaved
                                                        text: "󰌾 Saved"
                                                        font.pixelSize: 10
                                                        color: root.themeColors.accent ?? "#7aa2f7"
                                                    }
                                                }

                                                Text {
                                                    text: (security !== "" && security !== "--" ? "Secured" : "Open") + " • " + signal + "%"
                                                    color: root.themeColors.text_secondary ?? "#565f89"
                                                    font.pixelSize: 11
                                                }
                                            }

                                            // Connected: Disconnect Button
                                            Rectangle {
                                                visible: inUse
                                                Layout.preferredWidth: 80
                                                Layout.preferredHeight: 26
                                                radius: 6
                                                color: "#f44336"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Disconnect"
                                                    color: "white"
                                                    font.bold: true; font.pixelSize: 11
                                                }

                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        wifiDisconnecter.command = ["sh", "-c", "nmcli connection down id '" + ssid + "' || nmcli dev disconnect wlan0"];
                                                        wifiDisconnecter.running = true;
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: !inUse
                                                text: isExpanded ? "󰅃" : "󰅀"
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                                color: root.themeColors.text_secondary ?? "#565f89"
                                            }
                                        }

                                        // Action Options Drawer (Connect / Forget / Trust)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            visible: !inUse && isExpanded && !showPassword
                                            spacing: 6

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 26
                                                radius: 6
                                                color: root.themeColors.accent ?? "#7aa2f7"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Connect"
                                                    color: root.themeColors.bg ?? "#16161e"
                                                    font.bold: true; font.pixelSize: 11
                                                }

                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        var isOpen = (security === "" || security === "--");
                                                        if (isSaved || isOpen) {
                                                            wifiConnector.command = ["sh", "-c", "nmcli connection up id '" + ssid + "' 2>/dev/null || nmcli dev wifi connect '" + ssid + "'"];
                                                            wifiConnector.running = true;
                                                            wifiModel.setProperty(index, "isExpanded", false);
                                                        } else {
                                                            wifiModel.setProperty(index, "showPassword", true);
                                                            Qt.callLater(() => passField.forceActiveFocus());
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 26
                                                radius: 6
                                                color: root.themeColors.hover_bg ?? "#24283b"
                                                border.width: 1
                                                border.color: root.themeColors.border ?? "#16161e"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Forget"
                                                    color: root.themeColors.text_primary ?? "white"
                                                    font.bold: true; font.pixelSize: 11
                                                }

                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        wifiForgetRunner.command = ["sh", "-c", "nmcli connection delete id '" + ssid + "' || true"];
                                                        wifiForgetRunner.running = true;
                                                        wifiModel.setProperty(index, "isSaved", false);
                                                        wifiModel.setProperty(index, "isExpanded", false);
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 26
                                                radius: 6
                                                color: root.themeColors.hover_bg ?? "#24283b"
                                                border.width: 1
                                                border.color: root.themeColors.border ?? "#16161e"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Trust"
                                                    color: root.themeColors.text_primary ?? "white"
                                                    font.bold: true; font.pixelSize: 11
                                                }

                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        wifiTrustRunner.command = ["sh", "-c", "nmcli connection modify id '" + ssid + "' connection.autoconnect yes || true"];
                                                        wifiTrustRunner.running = true;
                                                        wifiModel.setProperty(index, "isExpanded", false);
                                                    }
                                                }
                                            }
                                        }

                                        // Password Entry Drawer
                                        RowLayout {
                                            Layout.fillWidth: true
                                            visible: !inUse && isExpanded && showPassword
                                            spacing: 6

                                            TextField {
                                                id: passField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                placeholderText: "Enter Password..."
                                                placeholderTextColor: root.themeColors.text_secondary ?? "#565f89"
                                                echoMode: TextInput.Password
                                                color: root.themeColors.text_primary ?? "white"
                                                font.pixelSize: 12
                                                verticalAlignment: TextInput.AlignVCenter
                                                selectByMouse: true

                                                background: Rectangle {
                                                    color: root.themeColors.bg ?? "#16161e"
                                                    radius: 6
                                                    border.width: 1
                                                    border.color: passField.activeFocus ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.border ?? "#16161e")
                                                }

                                                Keys.onReturnPressed: joinBtn.submitConnection()
                                                Keys.onEnterPressed: joinBtn.submitConnection()
                                            }

                                            Rectangle {
                                                id: joinBtn
                                                Layout.preferredWidth: 46
                                                Layout.preferredHeight: 28
                                                radius: 6
                                                color: root.themeColors.accent ?? "#7aa2f7"

                                                function submitConnection() {
                                                    var cmd = "nmcli dev wifi connect '" + ssid + "' password '" + passField.text + "'";
                                                    wifiConnector.command = ["sh", "-c", cmd];
                                                    wifiConnector.running = true;
                                                    wifiModel.setProperty(index, "isExpanded", false);
                                                    wifiModel.setProperty(index, "showPassword", false);
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Join"
                                                    color: root.themeColors.bg ?? "#16161e"
                                                    font.bold: true; font.pixelSize: 11
                                                }

                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: joinBtn.submitConnection()
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 32
                                                Layout.preferredHeight: 28
                                                radius: 6
                                                color: root.themeColors.hover_bg ?? "#24283b"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    color: root.themeColors.text_secondary ?? "#565f89"
                                                    font.pixelSize: 11
                                                }

                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        wifiModel.setProperty(index, "showPassword", false);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Touch listener for top of card
                                    MouseArea {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 44
                                        enabled: !inUse
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var nextState = !isExpanded;
                                            for (var k = 0; k < wifiModel.count; k++) {
                                                if (k !== index) {
                                                    wifiModel.setProperty(k, "isExpanded", false);
                                                    wifiModel.setProperty(k, "showPassword", false);
                                                }
                                            }
                                            wifiModel.setProperty(index, "isExpanded", nextState);
                                            wifiModel.setProperty(index, "showPassword", false);
                                        }
                                    }
                                }
                            }
                        }

                        // SUB-VIEW 2: HOTSPOT MANAGEMENT VIEW
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.networkActiveTab === "hotspot"
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: root.themeColors.card_bg ?? "#1f2335"
                                border.width: 1
                                border.color: root.hotspotActive ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.border ?? "#16161e")

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 14

                                    // Hotspot Status Header
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Rectangle {
                                            width: 36; height: 36; radius: 18
                                            color: root.hotspotActive ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.hover_bg ?? "#24283b")
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰖪"
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                                                color: root.hotspotActive ? (root.themeColors.bg ?? "#16161e") : (root.themeColors.text_secondary ?? "#565f89")
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: "Access Point Hotspot"
                                                font.bold: true; font.pixelSize: 14
                                                color: root.themeColors.text_primary ?? "white"
                                            }
                                            Text {
                                                text: root.hotspotActive ? "Broadcasting live" : "Inactive"
                                                font.pixelSize: 11
                                                color: root.hotspotActive ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.text_secondary ?? "#565f89")
                                            }
                                        }
                                    }

                                    // SSID Input Field
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: "Hotspot Name (SSID)"
                                            font.pixelSize: 11; font.bold: true
                                            color: root.themeColors.text_secondary ?? "#565f89"
                                        }

                                        TextField {
                                            id: hotspotSsidField
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            text: root.hotspotSsid
                                            color: root.themeColors.text_primary ?? "white"
                                            font.pixelSize: 13
                                            verticalAlignment: TextInput.AlignVCenter
                                            selectByMouse: true
                                            onTextChanged: root.hotspotSsid = text

                                            background: Rectangle {
                                                color: root.themeColors.bg ?? "#16161e"
                                                radius: 6
                                                border.width: 1
                                                border.color: hotspotSsidField.activeFocus ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.border ?? "#16161e")
                                            }
                                        }
                                    }

                                    // Password Input Field
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: "Password (Min 8 Characters)"
                                            font.pixelSize: 11; font.bold: true
                                            color: root.themeColors.text_secondary ?? "#565f89"
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            TextField {
                                                id: hotspotPassField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                text: root.hotspotPass
                                                echoMode: root.hotspotShowPassword ? TextInput.Normal : TextInput.Password
                                                color: root.themeColors.text_primary ?? "white"
                                                font.pixelSize: 13
                                                verticalAlignment: TextInput.AlignVCenter
                                                selectByMouse: true
                                                onTextChanged: root.hotspotPass = text

                                                background: Rectangle {
                                                    color: root.themeColors.bg ?? "#16161e"
                                                    radius: 6
                                                    border.width: 1
                                                    border.color: hotspotPassField.activeFocus ? (root.themeColors.accent ?? "#7aa2f7") : (root.themeColors.border ?? "#16161e")
                                                }
                                            }

                                            // Show / Hide Password Toggle
                                            Rectangle {
                                                Layout.preferredWidth: 32
                                                Layout.preferredHeight: 32
                                                radius: 6
                                                color: root.themeColors.hover_bg ?? "#24283b"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.hotspotShowPassword ? "󰈈" : "󰈉"
                                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                                    color: root.themeColors.text_primary ?? "white"
                                                }

                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.hotspotShowPassword = !root.hotspotShowPassword
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    // Primary Enable / Disable Toggle Action
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        radius: 8
                                        color: root.hotspotActive ? "#f44336" : (root.themeColors.accent ?? "#7aa2f7")
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 8
                                            Text {
                                                text: root.hotspotActive ? "󰐥" : "󰖪"
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                                color: root.hotspotActive ? "white" : (root.themeColors.bg ?? "#16161e")
                                            }
                                            Text {
                                                text: root.hotspotActive ? "Stop Hotspot" : "Start Hotspot"
                                                font.bold: true; font.pixelSize: 13
                                                color: root.hotspotActive ? "white" : (root.themeColors.bg ?? "#16161e")
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.toggleHotspot(!root.hotspotActive);
                                            }
                                        }
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
