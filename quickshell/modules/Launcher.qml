import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: launcher
    spacing: 10

    property alias searchInput: searchInput
    property var allApps: []
    ListModel { id: filteredAppModel }

    // Power User Card States
    property bool isMathActive: false
    property string mathResult: ""
    property string mathRawResult: ""
    property string mathExpr: ""

    property bool isBangActive: false
    property string bangType: ""
    property string bangQuery: ""
    property string bangLabel: ""
    property string bangIcon: ""

    property bool isCmdActive: false
    property string cmdText: ""
    property bool isCmdInteractive: false

    property bool isCopiedFeedback: false

    readonly property bool hasPowerCard: isMathActive || isBangActive || isCmdActive
    readonly property int calculatedCount: filteredAppModel.count + (hasPowerCard ? 1 : 0)
    readonly property color accentColor: Theme.colors.accent ?? "#7aa2f7"

    // Caelestia-flavoured emphasized-decelerate curve
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    Component.onCompleted: appScanner.running = true

    onVisibleChanged: {
        if (visible) {
            appList.positionViewAtBeginning();
            if (allApps.length === 0 && !appScanner.running) {
                appScanner.running = true;
            } else {
                launcher.processSearch(searchInput.text);
            }
            appList.currentIndex = filteredAppModel.count > 0 ? 0 : -1;
        } else {
            launcher.isCopiedFeedback = false;
        }
    }

    function rescanApps() {
        if (appScanner.running) appScanner.running = false;
        appScanner.running = true;
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

    // ========================================================
    // POWER USER: MATH, BANGS, & SHELL COMMAND PARSING
    // ========================================================
    function safeMathEval(expr) {
        var trimmed = expr.trim();
        if (trimmed.length < 2) return null;

        // Clean & sanitize
        var s = trimmed.replace(/,/g, '').replace(/x/g, '*').trim();
        s = s.replace(/(\d+(\.\d+)?)\s*%\s*of\s*(\d+(\.\d+)?)/gi, "($1/100)*$3");
        s = s.replace(/(\d+(\.\d+)?)\s*%/g, "($1/100)");
        s = s.replace(/\bsqrt\b/gi, "Math.sqrt")
             .replace(/\bsin\b/gi, "Math.sin")
             .replace(/\bcos\b/gi, "Math.cos")
             .replace(/\btan\b/gi, "Math.tan")
             .replace(/\babs\b/gi, "Math.abs")
             .replace(/\blog\b/gi, "Math.log")
             .replace(/\bpi\b/gi, "Math.PI")
             .replace(/\be\b/gi, "Math.E")
             .replace(/\^/g, "**");

        // Allowed character whitelist
        if (!/^[0-9\.\s\+\-\*\/\(\)\Math\.A-Z_]+$/.test(s)) return null;
        if (!/[\+\-\*\/\%]/.test(s) && !s.includes("Math.")) return null;

        try {
            var res = Function('"use strict"; return (' + s + ')')();
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                var rawStr = res.toString();
                var formatted = Number.isInteger(res) ? res.toLocaleString() : parseFloat(res.toFixed(5)).toLocaleString();
                return { formatted: formatted, raw: rawStr };
            }
        } catch(e) {}
        return null;
    }

    Timer {
        id: unitCalcDebounce
        interval: 120
        repeat: false
        property string pendingQuery: ""
        onTriggered: {
            if (pendingQuery !== "") {
                calcProcess.command = [(Quickshell.shellDir || Quickshell.configDir) + "/scripts/calc_helper.py", pendingQuery];
                calcProcess.running = true;
            }
        }
    }

    Process {
        id: calcProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim();
                if (out !== "" && !out.startsWith("error")) {
                    launcher.mathResult = out;
                    launcher.mathRawResult = out;
                    launcher.isMathActive = true;
                }
            }
        }
    }

    function isInteractiveTool(cmd) {
        var clean = cmd.trim();
        var firstWord = clean.split(/\s+/)[0].toLowerCase();
        var tools = [
            "htop", "btop", "top", "nvtop", "yazi", "ranger", "nnn", "mc",
            "nano", "vim", "nvim", "vi", "emacs", "micro",
            "less", "more", "man", "info",
            "bash", "zsh", "fish", "sh", "tmux", "screen",
            "ssh", "sftp", "gdb", "python", "python3", "ipython", "node"
        ];
        return tools.includes(firstWord);
    }

    function processSearch(filterText) {
        var raw = filterText.trim();

        // 1. Reset Power States
        launcher.isMathActive = false;
        launcher.isBangActive = false;
        launcher.isCmdActive = false;
        launcher.mathResult = "";
        launcher.mathRawResult = "";

        // 2. Check for Shell Command Prefix (">")
        if (raw.startsWith(">")) {
            var cmd = raw.substring(1).trim();
            if (cmd.length > 0) {
                launcher.isCmdActive = true;
                launcher.cmdText = cmd;
                launcher.isCmdInteractive = launcher.isInteractiveTool(cmd);
                filteredAppModel.clear();
                return;
            }
        }

        // 3. Check for Bangs ("!")
        if (raw.startsWith("!")) {
            var bangParts = raw.split(/\s+/);
            var bang = bangParts[0].toLowerCase();
            var bQuery = raw.substring(bang.length).trim();

            var bangMap = {
                "!g":     { label: "Search Google for \"" + bQuery + "\"", icon: "󰊭", type: "google" },
                "!gh":    { label: "Search GitHub for \"" + bQuery + "\"", icon: "󰊤", type: "github" },
                "!yt":    { label: "Search YouTube for \"" + bQuery + "\"", icon: "", type: "youtube" },
                "!w":     { label: "Search Wikipedia for \"" + bQuery + "\"", icon: "󰖟", type: "wikipedia" },
                "!aw":    { label: "Search ArchWiki for \"" + bQuery + "\"", icon: "󰣇", type: "archwiki" },
                "!arch":  { label: "Search ArchWiki for \"" + bQuery + "\"", icon: "󰣇", type: "archwiki" },
                "!d":     { label: "Search DuckDuckGo for \"" + bQuery + "\"", icon: "󰇥", type: "ddg" },
                "!ddg":   { label: "Search DuckDuckGo for \"" + bQuery + "\"", icon: "󰇥", type: "ddg" },
                "!keys":  { label: "Open Hyprland Keybind Cheat Sheet", icon: "󰌌", type: "keys" },
                "!?":     { label: "Open Hyprland Keybind Cheat Sheet", icon: "󰌌", type: "keys" },
                "!note":  { label: "Open Quick Scratchpad & Tasks", icon: "󰠮", type: "notes" },
                "!notes": { label: "Open Quick Scratchpad & Tasks", icon: "󰠮", type: "notes" },
                "!todo":  { label: "Open Quick Scratchpad & Tasks", icon: "󰠮", type: "notes" }
            };

            if (bangMap[bang]) {
                var bInfo = bangMap[bang];
                launcher.isBangActive = true;
                launcher.bangType = bInfo.type;
                launcher.bangQuery = bQuery;
                launcher.bangLabel = bInfo.label;
                launcher.bangIcon = bInfo.icon;
                filteredAppModel.clear();
                return;
            }
        }

        // 4. Check for Inline Math Evaluation
        var mathRes = launcher.safeMathEval(raw);
        if (mathRes !== null) {
            launcher.isMathActive = true;
            launcher.mathExpr = raw;
            launcher.mathResult = mathRes.formatted;
            launcher.mathRawResult = mathRes.raw;
        } else if (/\d+\s*[a-zA-Z]+\s+(to|in)\s+[a-zA-Z]+/i.test(raw)) {
            // Unit or Currency conversion candidate
            launcher.mathExpr = raw;
            unitCalcDebounce.pendingQuery = raw;
            unitCalcDebounce.restart();
        }

        // 5. Filter Desktop Applications
        filteredAppModel.clear();
        var query = raw.toLowerCase();
        for (var i = 0; i < allApps.length; i++) {
            var app = allApps[i];
            if (query === "" || launcher.isSubsequence(query, app.name.toLowerCase())) {
                filteredAppModel.append(app);
            }
        }
        appList.currentIndex = filteredAppModel.count > 0 ? 0 : -1;
        appList.positionViewAtBeginning();
    }

    function copyMathResult() {
        var toCopy = launcher.mathRawResult || launcher.mathResult;
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(toCopy) + " | wl-copy"]);
        launcher.isCopiedFeedback = true;
        Qt.callLater(() => {
            copyHideTimer.restart();
        });
    }

    Timer {
        id: copyHideTimer
        interval: 380
        repeat: false
        onTriggered: root.collapseToIdle()
    }

    function executeBang() {
        var q = launcher.bangQuery;
        var encoded = encodeURIComponent(q);
        root.collapseToIdle();

        if (launcher.bangType === "keys") {
            root.switchMode("cheatsheet", true);
        } else if (launcher.bangType === "notes") {
            root.switchMode("notes", true);
        } else if (launcher.bangType === "google") {
            Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encoded]);
        } else if (launcher.bangType === "github") {
            Quickshell.execDetached(["xdg-open", "https://github.com/search?q=" + encoded]);
        } else if (launcher.bangType === "youtube") {
            Quickshell.execDetached(["xdg-open", "https://www.youtube.com/results?search_query=" + encoded]);
        } else if (launcher.bangType === "wikipedia") {
            Quickshell.execDetached(["xdg-open", "https://en.wikipedia.org/wiki/Special:Search?search=" + encoded]);
        } else if (launcher.bangType === "archwiki") {
            Quickshell.execDetached(["xdg-open", "https://wiki.archlinux.org/index.php?search=" + encoded]);
        } else if (launcher.bangType === "ddg") {
            Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encoded]);
        }
    }

    function executeShellCmd(forceTerminal = false) {
        var cmd = launcher.cmdText.trim();
        if (cmd === "") return;
        root.collapseToIdle();

        if (forceTerminal || launcher.isCmdInteractive) {
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", cmd]);
        } else {
            Quickshell.execDetached(["sh", "-c", cmd + " &"]);
        }
    }

    function recordUsageAndLaunch(execCmd) {
        appRunner.command = ["sh", "-c", execCmd + " &"];
        appRunner.running = true;
        
        usageTracker.targetExec = execCmd;
        usageTracker.running = true;
        
        root.activeMode = "idle";
    }

    Process {
        id: usageTracker
        running: false
        property string targetExec: ""
        command: ["python3", "-c", `
import sys, os, json
f = os.path.expanduser('~/.cache/qs_app_usage.json')
d = {}
try:
    with open(f, 'r') as file: d = json.load(file)
except: pass
cmd = sys.argv[1]
d[cmd] = d.get(cmd, 0) + 1
with open(f, 'w') as file: json.dump(d, file)
        `, targetExec]
    }

    Process {
        id: appScanner
        running: false
        command: ["sh", "-c", `
            python3 -c "
import os, glob, re, json
apps = []
usage = {}
try:
    with open(os.path.expanduser('~/.cache/qs_app_usage.json'), 'r') as f: usage = json.load(f)
except: pass

icon_cache = {}
for base in ['/usr/share/pixmaps', os.path.expanduser('~/.local/share/icons')]:
    if os.path.exists(base):
        for root, dirs, files in os.walk(base):
            for f in files:
                name, ext = os.path.splitext(f)
                if ext.lower() in ('.png', '.svg', '.xpm') and name not in icon_cache:
                    icon_cache[name] = os.path.join(root, f)
for theme in ['breeze-dark', 'breeze', 'Adwaita', 'hicolor']:
    base = f'/usr/share/icons/{theme}'
    if os.path.exists(base):
        for root, dirs, files in os.walk(base):
            for f in files:
                name, ext = os.path.splitext(f)
                if ext.lower() in ('.png', '.svg') and name not in icon_cache:
                    icon_cache[name] = os.path.join(root, f)

def resolve_icon(i):
    if not i: return ''
    if os.path.isabs(i) and os.path.exists(i): return i
    return icon_cache.get(i, '')

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
                if name and exec_cmd:
                    n = name.group(1).strip()
                    e = re.sub(r'%[fFuUiDc]', '', exec_cmd.group(1)).strip()
                    i_raw = icon.group(1).strip() if (icon and icon.group(1)) else ''
                    i = resolve_icon(i_raw)
                    c = comment.group(1).strip() if comment else ''
                    u = usage.get(e, 0)
                    apps.append((u, n, e, i, c))
        except: pass
apps = sorted(list(set(apps)), key=lambda x: (-x[0], x[1].lower()))
for a in apps: print(f'{a[1]}|||{a[2]}|||{a[3]}|||{a[4]}')
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
                launcher.allApps = tempList;
                launcher.processSearch(searchInput.text);
            }
        }
    }

    Process { id: appRunner; running: false }

    // ========================================================
    // SEARCH BAR
    // ========================================================
    Rectangle {
        id: searchBar
        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: height / 2
        color: Theme.colors.card_bg ?? "#1f2335"
        border.width: 1.5
        border.color: searchInput.activeFocus ? launcher.accentColor : "transparent"
        Behavior on border.color { ColorAnimation { duration: 180 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 10
            spacing: 10

            Text {
                text: {
                    if (launcher.isMathActive) return "󱖦";
                    if (launcher.isCmdActive) return "󰞷";
                    if (launcher.isBangActive) return launcher.bangIcon || "󰊭";
                    return "⌕";
                }
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 17
                color: searchInput.activeFocus ? launcher.accentColor : (Theme.colors.text_secondary ?? "#a9b1d6")
                Behavior on color { ColorAnimation { duration: 180 } }
            }

            TextField {
                id: searchInput
                focus: true
                selectByMouse: true
                Layout.fillWidth: true
                color: Theme.colors.text_primary ?? "#c0caf5"
                font.family: "Inter"
                font.pixelSize: 15
                placeholderText: "Search apps, math (e.g. 1280*720), > cmd, !g search..."
                placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                background: Item {}

                onTextChanged: launcher.processSearch(text)

                Keys.onDownPressed: (event) => {
                    if (appList.currentIndex < filteredAppModel.count - 1) {
                        appList.currentIndex++;
                        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
                    }
                    event.accepted = true;
                }
                Keys.onUpPressed: (event) => {
                    if (appList.currentIndex > 0) {
                        appList.currentIndex--;
                        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
                    }
                    event.accepted = true;
                }
                Keys.onEscapePressed: root.activeMode = "idle"

                Keys.onReturnPressed: (event) => {
                    var isShift = (event.modifiers & Qt.ShiftModifier);
                    if (launcher.isMathActive) {
                        launcher.copyMathResult();
                        event.accepted = true;
                    } else if (launcher.isBangActive) {
                        launcher.executeBang();
                        event.accepted = true;
                    } else if (launcher.isCmdActive) {
                        launcher.executeShellCmd(isShift);
                        event.accepted = true;
                    } else if (filteredAppModel.count > 0 && appList.currentIndex >= 0) {
                        launcher.recordUsageAndLaunch(filteredAppModel.get(appList.currentIndex).exec);
                        event.accepted = true;
                    } else if (text.trim() !== "") {
                        appRunner.command = ["sh", "-c", text.trim() + " &"];
                        appRunner.running = true;
                        root.activeMode = "idle";
                        event.accepted = true;
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                visible: searchInput.text.length > 0
                color: clearMouse.containsMouse ? (Theme.colors.hover_bg ?? "#2a2f45") : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    color: Theme.colors.text_secondary ?? "#565f89"
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                }
            }
        }
    }

    // ========================================================
    // POWER USER CARDS (Math / Bang / Shell Command)
    // ========================================================
    // 1. Math Evaluation Card
    Rectangle {
        id: mathCard
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        visible: launcher.isMathActive && launcher.mathResult !== ""
        radius: 12
        color: launcher.isCopiedFeedback
            ? Qt.rgba(0.18, 0.83, 0.5, 0.22)
            : (mathMouse.containsMouse ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.18) : (Theme.colors.card_bg ?? "#1f2335"))
        border.width: 1.5
        border.color: launcher.isCopiedFeedback ? "#73daca" : launcher.accentColor
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 10
                color: launcher.isCopiedFeedback ? Qt.rgba(0.18, 0.83, 0.5, 0.25) : Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.2)

                Text {
                    anchors.centerIn: parent
                    text: launcher.isCopiedFeedback ? "✓" : "󱖦"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: launcher.isCopiedFeedback ? "#73daca" : launcher.accentColor
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Row {
                    spacing: 6
                    Text {
                        text: "= " + launcher.mathResult
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true
                        color: launcher.isCopiedFeedback ? "#73daca" : (Theme.colors.text_primary ?? "#c0caf5")
                    }
                }

                Text {
                    text: launcher.isCopiedFeedback ? "Copied answer to clipboard!" : (launcher.mathExpr + " · Press Enter or click to copy")
                    font.family: "Inter"
                    font.pixelSize: 11
                    color: launcher.isCopiedFeedback ? "#73daca" : (Theme.colors.text_secondary ?? "#565f89")
                }
            }

            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: 64
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: launcher.isCopiedFeedback ? "Copied" : "Enter ↵"
                    font.family: "Inter"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Theme.colors.text_primary ?? "white"
                }
            }
        }

        MouseArea {
            id: mathMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: launcher.copyMathResult()
        }
    }

    // 2. Search Bang Card
    Rectangle {
        id: bangCard
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        visible: launcher.isBangActive
        radius: 12
        color: bangMouse.containsMouse ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.18) : (Theme.colors.card_bg ?? "#1f2335")
        border.width: 1.5
        border.color: launcher.accentColor
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 10
                color: Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.2)

                Text {
                    anchors.centerIn: parent
                    text: launcher.bangIcon || "󰊭"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: launcher.accentColor
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    text: launcher.bangLabel
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.colors.text_primary ?? "#c0caf5"
                    elide: Text.ElideRight
                }

                Text {
                    text: (launcher.bangType === "keys" || launcher.bangType === "notes") ? "Press Enter to open module" : "Press Enter to search in default browser"
                    font.family: "Inter"
                    font.pixelSize: 11
                    color: Theme.colors.text_secondary ?? "#565f89"
                }
            }

            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: 64
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: "Search ↵"
                    font.family: "Inter"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Theme.colors.text_primary ?? "white"
                }
            }
        }

        MouseArea {
            id: bangMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: launcher.executeBang()
        }
    }

    // 3. Shell Command Card (">")
    Rectangle {
        id: cmdCard
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        visible: launcher.isCmdActive
        radius: 12
        color: cmdMouse.containsMouse ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.18) : (Theme.colors.card_bg ?? "#1f2335")
        border.width: 1.5
        border.color: launcher.accentColor
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 10
                color: Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.2)

                Text {
                    anchors.centerIn: parent
                    text: "󰞷"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: launcher.accentColor
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Row {
                    spacing: 6
                    Text {
                        text: "Run: " + launcher.cmdText
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.colors.text_primary ?? "#c0caf5"
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        height: 16
                        width: badgeText.implicitWidth + 8
                        radius: 8
                        color: launcher.isCmdInteractive ? Qt.rgba(0.48, 0.63, 0.97, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: launcher.isCmdInteractive ? "kitty" : "background"
                            font.family: "Inter"
                            font.pixelSize: 9
                            color: launcher.isCmdInteractive ? launcher.accentColor : (Theme.colors.text_secondary ?? "#565f89")
                        }
                    }
                }

                Text {
                    text: "Press Enter to execute · Shift+Enter to force in Kitty terminal"
                    font.family: "Inter"
                    font.pixelSize: 10
                    color: Theme.colors.text_secondary ?? "#565f89"
                }
            }

            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: 54
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: "Run ↵"
                    font.family: "Inter"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Theme.colors.text_primary ?? "white"
                }
            }
        }

        MouseArea {
            id: cmdMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: launcher.executeShellCmd(false)
        }
    }

    // ========================================================
    // RESULTS STATUS & APP LIST
    // ========================================================
    Text {
        Layout.leftMargin: 4
        visible: searchInput.text.trim() !== "" && !launcher.isBangActive && !launcher.isCmdActive
        text: filteredAppModel.count + (filteredAppModel.count === 1 ? " app result" : " app results")
        font.family: "Inter"
        font.pixelSize: 11
        font.weight: Font.Medium
        color: Theme.colors.text_secondary ?? "#565f89"
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !launcher.isBangActive && !launcher.isCmdActive

        ListView {
            id: appList
            anchors.fill: parent
            clip: true
            spacing: 4
            model: filteredAppModel
            currentIndex: 0
            
            highlightFollowsCurrentItem: true
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: 40
            preferredHighlightEnd: height - 56
            highlightMoveDuration: 120

            onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex < count) {
                    positionViewAtIndex(currentIndex, ListView.Contain);
                }
            }

            // Android-style fluid scrolling physics
            boundsBehavior: Flickable.DragAndOvershootBounds
            maximumFlickVelocity: 3500
            flickDeceleration: 2200

            // Minimal rounded scrollbar
            ScrollBar.vertical: ScrollBar { 
                policy: ScrollBar.AsNeeded
                width: 4
                contentItem: Rectangle { 
                    radius: 2
                    color: Theme.colors.text_secondary ?? "#565f89"
                    opacity: 0.4 
                } 
            }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
            addDisplaced: Transition { NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }
            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
            displaced: Transition { NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }

            delegate: Rectangle {
                id: delegateRoot
                width: ListView.view.width
                height: comment !== "" ? 54 : 42
                property bool isSelected: ListView.isCurrentItem
                property string appName: name
                property string appExec: exec
                radius: 12
                color: isSelected
                    ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.18)
                    : (appMouse.containsMouse ? (Theme.colors.card_bg ?? "#1f2335") : "transparent")
                scale: appMouse.pressed ? 0.98 : 1.0

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.BezierSpline; easing.bezierCurve: launcher.motionCurve } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 12
                    anchors.topMargin: 4;  anchors.bottomMargin: 4
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        radius: 11
                        color: delegateRoot.isSelected
                            ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.24)
                            : (Theme.colors.card_bg ?? "#1f2335")
                        Behavior on color { ColorAnimation { duration: 150 } }

                        // Fallback modern app grid icon (shown when app has no icon or failed to load)
                        Item {
                            anchors.fill: parent
                            visible: !appIcon.visible

                            Text {
                                anchors.centerIn: parent
                                text: "󰀻"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                color: delegateRoot.isSelected
                                    ? launcher.accentColor
                                    : (Theme.colors.text_secondary ?? "#565f89")
                            }
                        }

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            anchors.margins: 6
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 32
                            sourceSize.height: 32
                            visible: status === Image.Ready && source != ""
                            
                            source: {
                                if (iconName === "") return "";
                                if (iconName.startsWith("/")) return "file://" + iconName;
                                return "image://icon/" + iconName;
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
                            color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_primary ?? "#c0caf5")
                            font.family: "Inter"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: comment !== "" ? comment : exec
                            color: delegateRoot.isSelected ? (Theme.colors.text_primary ?? "#a9b1d6") : (Theme.colors.text_secondary ?? "#565f89")
                            font.family: "Inter"
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
                    cursorShape: Qt.PointingHandCursor
                    onEntered: appList.currentIndex = index
                    onClicked: launcher.recordUsageAndLaunch(appExec)
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: filteredAppModel.count === 0 && searchInput.text.trim() !== "" && !launcher.isMathActive

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰍉"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 22
                color: Theme.colors.text_secondary ?? "#565f89"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No apps found"
                font.family: "Inter"
                font.pixelSize: 12
                color: Theme.colors.text_secondary ?? "#565f89"
            }
        }
    }
}