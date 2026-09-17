import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root

    property bool open: false
    property real presentation: 0.0
    Behavior on presentation {
        NumberAnimation {
            duration: 180
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
        }
    }

    onOpenChanged: {
        if (open) {
            presentation = 1.0;
            Qt.callLater(() => { input.forceActiveFocus(); });
        } else {
            presentation = 0.0;
        }
    }

    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:iris-spotlight"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }

    // Styling constants matching Iris
    readonly property color accentColor: Theme.colors.accent ? Theme.colors.accent : "#7aa2f7"
    readonly property color secondaryAccent: "#ff9f0a"
    readonly property color colSurface: "#000000"
    readonly property color colHairline: "#262628"
    readonly property color colText: "#f5f5f7"
    readonly property color colSubtext: "#aeaeb2"
    readonly property color colMuted: "#8e8e93"

    // Search prefixes matching Iris
    readonly property string prefixClipboard: ";"
    readonly property string prefixMath: "="
    readonly property string prefixAction: "/"
    readonly property string prefixEmoji: ":"
    readonly property string prefixWeb: "?"
    readonly property string prefixCommand: "$"

    property string query: ""
    readonly property bool browsing: query.length === 0
    readonly property bool clipboardMode: query.startsWith(prefixClipboard)
    readonly property bool mathMode: query.startsWith(prefixMath) || (!query.startsWith(";") && !query.startsWith("/") && !query.startsWith(":") && !query.startsWith("?") && !query.startsWith("$") && !query.startsWith(">") && /[0-9]/.test(query) && /[\+\-\*\/\%]|sqrt|sin|cos|tan|\^|\bto\b|\bin\b/.test(query))
    readonly property bool actionMode: query.startsWith(prefixAction)
    readonly property bool emojiMode: query.startsWith(prefixEmoji)
    readonly property bool webMode: query.startsWith(prefixWeb)
    readonly property bool commandMode: query.startsWith(prefixCommand) || query.startsWith(">")

    property int selectedIndex: 0
    property bool pointerSelectionArmed: false
    property point lastPointerPosition: Qt.point(-1, -1)

    // Data stores
    property var allApps: []
    property var runningClients: []
    property var suggestions: []
    property var clipboardEntries: []
    property string mathResult: ""
    property string mathRaw: ""

    // Emojis dataset
    readonly property var emojisList: [
        { emoji: "😀", name: "grinning face happy" },
        { emoji: "😂", name: "face with tears of joy laugh lol" },
        { emoji: "🤣", name: "rolling on the floor laughing rofl" },
        { emoji: "😊", name: "smiling face with smiling eyes smile" },
        { emoji: "😍", name: "smiling face with heart-eyes love heart" },
        { emoji: "🥰", name: "smiling face with hearts adore" },
        { emoji: "😘", name: "face blowing a kiss kiss" },
        { emoji: "😎", name: "smiling face with sunglasses cool" },
        { emoji: "🔥", name: "fire flame lit hot" },
        { emoji: "✨", name: "sparkles shiny magic" },
        { emoji: "🎉", name: "party popper celebration celebrate party" },
        { emoji: "🚀", name: "rocket ship blast off fast" },
        { emoji: "👍", name: "thumbs up approve yes good" },
        { emoji: "👎", name: "thumbs down disapprove no bad" },
        { emoji: "❤️", name: "red heart love" },
        { emoji: "💯", name: "hundred points perfect score 100" },
        { emoji: "🤔", name: "thinking face think wonder hmm" },
        { emoji: "👀", name: "eyes look see watching" },
        { emoji: "🙏", name: "folded hands please pray thank you" },
        { emoji: "⚡", name: "high voltage lightning bolt power" },
        { emoji: "💻", name: "laptop computer tech code" },
        { emoji: "💡", name: "light bulb idea smart" },
        { emoji: "☕", name: "hot beverage coffee tea" },
        { emoji: "✅", name: "check mark button check done ok" },
        { emoji: "❌", name: "cross mark x no wrong cancel" },
        { emoji: "⭐", name: "star favorite" },
        { emoji: "🥳", name: "partying face woohoo celebration" },
        { emoji: "😴", name: "sleeping face tired zzz sleep" },
        { emoji: "💀", name: "skull dead dead dying laugh" },
        { emoji: "🫡", name: "saluting face respect yes sir" },
        { emoji: "🥺", name: "pleading face please puppy eyes" },
        { emoji: "😭", name: "loudly crying face sob sad cry" }
    ]

    // System actions dataset
    readonly property var actionsList: [
        { name: "Lock Screen", cmd: "hyprlock", icon: "lock", action: "lock" },
        { name: "Suspend System", cmd: "systemctl suspend", icon: "bedtime", action: "suspend" },
        { name: "Restart Computer", cmd: "systemctl reboot", icon: "restart_alt", action: "restart" },
        { name: "Shut Down", cmd: "systemctl poweroff", icon: "power_settings_new", action: "shutdown" },
        { name: "Screen Snip / Capture", cmd: "grim -g \"$(slurp)\" - | wl-copy", icon: "screenshot_monitor", action: "screenshot" },
        { name: "Text OCR Capture", cmd: "bash " + Quickshell.configDir + "/../my_own/scripts/snip_ocr.sh", icon: "document_scanner", action: "ocr" },
        { name: "Toggle Do Not Disturb", cmd: "notify-send 'DND toggled'", icon: "notifications_off", action: "dnd" },
        { name: "Reload Shell", cmd: "~/.config/quickshell/reload.sh &", icon: "refresh", action: "reload" },
        { name: "Open Terminal", cmd: "kitty", icon: "terminal", action: "terminal" },
        { name: "Open File Manager", cmd: "xdg-open ~", icon: "folder_open", action: "files" }
    ]

    function disarmPointerSelection(resetPosition = false) {
        root.pointerSelectionArmed = false;
        if (resetPosition) root.lastPointerPosition = Qt.point(-1, -1);
    }

    function armPointerSelection(area, event) {
        var point = area.mapToItem(null, event.x, event.y);
        if (root.lastPointerPosition.x < 0 || root.lastPointerPosition.y < 0) {
            root.lastPointerPosition = Qt.point(point.x, point.y);
            return false;
        }
        var moved = Math.abs(point.x - root.lastPointerPosition.x) > 0.5
            || Math.abs(point.y - root.lastPointerPosition.y) > 0.5;
        root.lastPointerPosition = Qt.point(point.x, point.y);
        if (moved) root.pointerSelectionArmed = true;
        return root.pointerSelectionArmed;
    }

    function toggle() {
        if (root.open) root.close();
        else root.openWindow();
    }

    function openWindow() {
        root.open = true;
        root.selectedIndex = 0;
        root.disarmPointerSelection(true);
        refreshRunningWindows();
        if (allApps.length === 0 && !appScanner.running) {
            appScanner.running = true;
        }
        Qt.callLater(() => {
            input.forceActiveFocus();
        });
    }

    function close() {
        root.open = false;
        input.text = "";
    }

    // Refresh running windows from hyprctl
    function refreshRunningWindows() {
        clientScanner.running = true;
    }

    Process {
        id: clientScanner
        running: false
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var clients = JSON.parse(this.text);
                    root.runningClients = clients || [];
                } catch(e) {
                    root.runningClients = [];
                }
                root.updateSuggestions();
            }
        }
    }

    // Desktop Application Scanner
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
    return icon_cache.get(i, i)

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
                root.allApps = tempList;
                root.updateSuggestions();
            }
        }
    }

    Component.onCompleted: {
        appScanner.running = true;
    }

    // Update Dock/Suggestions apps row (up to 8 items)
    function updateSuggestions() {
        var list = [];
        var seenNames = {};

        // 1. Running Apps from Hyprland
        for (var c = 0; c < root.runningClients.length; c++) {
            var client = root.runningClients[c];
            if (!client || !client.class) continue;
            var cClass = client.class.toLowerCase();
            var cTitle = client.initialTitle || client.title || client.class;
            
            // Find corresponding desktop entry
            var matchedApp = null;
            for (var a = 0; a < root.allApps.length; a++) {
                var app = root.allApps[a];
                var aName = app.name.toLowerCase();
                var aExec = app.exec.toLowerCase();
                if (aExec.includes(cClass) || aName.includes(cClass) || cClass.includes(aName)) {
                    matchedApp = app;
                    break;
                }
            }

            var appName = matchedApp ? matchedApp.name : (client.initialClass || client.class);
            if (seenNames[appName.toLowerCase()]) continue;
            seenNames[appName.toLowerCase()] = true;

            list.push({
                name: appName,
                iconName: matchedApp ? matchedApp.iconName : client.class.toLowerCase(),
                exec: matchedApp ? matchedApp.exec : client.class,
                running: true,
                address: client.address,
                verb: "Switch to"
            });
            if (list.length >= 8) break;
        }

        // 2. Favorite / Pinned Defaults to fill up to 8
        var defaults = [
            { name: "Zen Browser", match: "zen", fallbackIcon: "zen" },
            { name: "Kitty", match: "kitty", fallbackIcon: "kitty" },
            { name: "Spotify", match: "spotify", fallbackIcon: "spotify" },
            { name: "Code", match: "code", fallbackIcon: "visual-studio-code" },
            { name: "Files", match: "thunar", fallbackIcon: "system-file-manager" },
            { name: "Discord", match: "discord", fallbackIcon: "discord" },
            { name: "Settings", match: "settings", fallbackIcon: "preferences-system" },
            { name: "Terminal", match: "terminal", fallbackIcon: "utilities-terminal" }
        ];

        for (var d = 0; d < defaults.length && list.length < 8; d++) {
            var def = defaults[d];
            if (seenNames[def.name.toLowerCase()]) continue;

            var found = null;
            for (var k = 0; k < root.allApps.length; k++) {
                var cur = root.allApps[k];
                if (cur.name.toLowerCase().includes(def.match) || cur.exec.toLowerCase().includes(def.match)) {
                    found = cur;
                    break;
                }
            }

            seenNames[def.name.toLowerCase()] = true;
            list.push({
                name: found ? found.name : def.name,
                iconName: found ? found.iconName : def.fallbackIcon,
                exec: found ? found.exec : def.match,
                running: false,
                address: "",
                verb: "Open"
            });
        }

        // 3. Still need items? Use top scanned apps
        for (var j = 0; j < root.allApps.length && list.length < 8; j++) {
            var topApp = root.allApps[j];
            if (seenNames[topApp.name.toLowerCase()]) continue;
            seenNames[topApp.name.toLowerCase()] = true;
            list.push({
                name: topApp.name,
                iconName: topApp.iconName,
                exec: topApp.exec,
                running: false,
                address: "",
                verb: "Open"
            });
        }

        root.suggestions = list.slice(0, 8);
    }

    // Cliphist Loader
    Process {
        id: cliphistProc
        running: false
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var result = [];
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim();
                    if (l.length > 0) result.push(l);
                    if (result.length >= 40) break;
                }
                root.clipboardEntries = result;
            }
        }
    }

    onClipboardModeChanged: {
        if (root.clipboardMode) {
            cliphistProc.running = true;
        }
    }

    // Math Evaluation Engine
    function safeMathEval(expr) {
        var clean = expr.trim();
        if (clean.startsWith("=")) clean = clean.substring(1).trim();
        if (clean.length < 1) return null;

        var s = clean.replace(/,/g, '').replace(/x/g, '*').trim();
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
        id: qalcDebounce
        interval: 100
        repeat: false
        property string pendingExpr: ""
        onTriggered: {
            if (pendingExpr.length > 0) {
                qalcProc.calculate(pendingExpr);
            }
        }
    }

    Process {
        id: qalcProc
        running: false
        property string targetExpr: ""
        function calculate(expr) {
            var clean = expr.trim();
            if (clean.startsWith("=")) clean = clean.substring(1).trim();
            qalcProc.targetExpr = clean;
            qalcProc.running = false;
            qalcProc.command = ["qalc", "-t", clean];
            qalcProc.running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim();
                if (out.length > 0 && !out.toLowerCase().startsWith("error")) {
                    root.mathResult = out;
                    root.mathRaw = out;
                }
            }
        }
    }

    // Apple-style substring match emphasis helper
    function escapeHtml(value) {
        return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function emphasised(name, q) {
        var queryTrim = q.trim();
        var at = queryTrim.length > 0 ? name.toLowerCase().indexOf(queryTrim.toLowerCase()) : -1;
        var dim = root.colSubtext;
        if (at < 0) return "<font color='" + root.colText + "'>" + escapeHtml(name) + "</font>";
        return "<font color='" + dim + "'>" + escapeHtml(name.slice(0, at)) + "</font>"
            + "<b><font color='" + root.colText + "'>" + escapeHtml(name.slice(at, at + queryTrim.length)) + "</font></b>"
            + "<font color='" + dim + "'>" + escapeHtml(name.slice(at + queryTrim.length)) + "</font>";
    }

    // Results Generation
    readonly property var visibleResults: {
        if (root.browsing) return root.suggestions;

        var q = root.query.trim();
        var res = [];

        // 1. Clipboard History Mode (;)
        if (root.clipboardMode) {
            var clipQuery = q.substring(1).trim().toLowerCase();
            for (var c = 0; c < root.clipboardEntries.length; c++) {
                var entry = root.clipboardEntries[c];
                var tabIdx = entry.indexOf("\t");
                var entryId = tabIdx >= 0 ? entry.substring(0, tabIdx) : "";
                var entryText = tabIdx >= 0 ? entry.substring(tabIdx + 1) : entry;
                var isImage = entryText.includes("[[ binary data");

                if (clipQuery.length === 0 || entryText.toLowerCase().includes(clipQuery)) {
                    res.push({
                        type: "Clipboard history",
                        name: isImage ? "Image" : entryText,
                        comment: isImage ? entryText : "",
                        icon: "content_paste",
                        isIconMaterial: true,
                        isClipImage: isImage,
                        entryId: entryId,
                        rawValue: entry,
                        verb: "Copy",
                        execute: function(item) {
                            Quickshell.execDetached(["sh", "-c", "echo " + JSON.stringify(item.rawValue) + " | cliphist decode | wl-copy"]);
                            root.close();
                        }
                    });
                }
                if (res.length >= 8) break;
            }
            return res;
        }

        // 2. Emoji Mode (:)
        if (root.emojiMode) {
            var emojiQuery = q.substring(1).trim().toLowerCase();
            for (var e = 0; e < root.emojisList.length; e++) {
                var em = root.emojisList[e];
                if (emojiQuery.length === 0 || em.name.toLowerCase().includes(emojiQuery)) {
                    res.push({
                        type: "Emoji",
                        name: em.emoji + "  " + em.name,
                        emojiChar: em.emoji,
                        icon: em.emoji,
                        isIconText: true,
                        comment: em.name,
                        verb: "Copy",
                        execute: function(item) {
                            Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(item.emojiChar) + " | wl-copy"]);
                            root.close();
                        }
                    });
                }
                if (res.length >= 8) break;
            }
            return res;
        }

        // 3. Actions Mode (/)
        if (root.actionMode) {
            var actionQuery = q.substring(1).trim().toLowerCase();
            for (var a = 0; a < root.actionsList.length; a++) {
                var act = root.actionsList[a];
                if (actionQuery.length === 0 || act.name.toLowerCase().includes(actionQuery) || act.action.toLowerCase().includes(actionQuery)) {
                    res.push({
                        type: "Actions",
                        name: act.name,
                        icon: act.icon,
                        isIconMaterial: true,
                        comment: "/" + act.action,
                        verb: "Run",
                        execute: function(item) {
                            root.close();
                            // Use quickshell global shortcuts for special actions
                            Quickshell.execDetached(["sh", "-c", act.cmd + " &"]);
                        }
                    });
                }
                if (res.length >= 8) break;
            }
            return res;
        }

        // 4. Web Search Mode (?)
        if (root.webMode) {
            var webQuery = q.substring(1).trim();
            res.push({
                type: "Search the web",
                name: "Search Google for \"" + webQuery + "\"",
                icon: "travel_explore",
                isIconMaterial: true,
                comment: "https://www.google.com/search?q=" + encodeURIComponent(webQuery),
                verb: "Search",
                execute: function() {
                    Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(webQuery)]);
                    root.close();
                }
            });
            return res;
        }

        // 5. Shell Command Mode ($ or >)
        if (root.commandMode) {
            var cmdQuery = q.startsWith("$") ? q.substring(1).trim() : q.substring(1).trim();
            res.push({
                type: "Run command",
                name: cmdQuery,
                icon: "terminal",
                isIconMaterial: true,
                comment: "Execute in shell",
                verb: "Run",
                execute: function() {
                    root.close();
                    var tools = ["htop", "btop", "top", "nvtop", "yazi", "ranger", "nnn", "nano", "vim", "nvim", "less"];
                    var first = cmdQuery.split(/\s+/)[0].toLowerCase();
                    if (tools.includes(first)) {
                        Quickshell.execDetached(["kitty", "-e", "sh", "-c", cmdQuery]);
                    } else {
                        Quickshell.execDetached(["sh", "-c", cmdQuery + " &"]);
                    }
                }
            });
            return res;
        }

        // 6. Math Result (Instant JS eval or debounced Qalc)
        var mathCandidate = root.mathMode || q.startsWith("=");
        if (mathCandidate) {
            var immediate = root.safeMathEval(q);
            var mVal = immediate ? immediate.formatted : root.mathResult;
            if (mVal.length > 0) {
                res.push({
                    type: "Calculator",
                    name: mVal,
                    icon: "calculate",
                    isIconMaterial: true,
                    isMathHit: true,
                    comment: q.startsWith("=") ? q.substring(1).trim() : q,
                    verb: "Copy",
                    execute: function(item) {
                        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(item.name) + " | wl-copy"]);
                        root.close();
                    }
                });
            }
        }

        // 7. Desktop Applications (Fuzzy & Substring match)
        var queryLower = q.toLowerCase();
        var appMatches = [];
        for (var i = 0; i < root.allApps.length; i++) {
            var appItem = root.allApps[i];
            var appNameLower = appItem.name.toLowerCase();
            var appExecLower = appItem.exec.toLowerCase();

            var score = -1;
            if (appNameLower === queryLower) score = 100;
            else if (appNameLower.startsWith(queryLower)) score = 80;
            else if (appNameLower.includes(queryLower)) score = 60;
            else if (appExecLower.startsWith(queryLower)) score = 50;
            else if (appExecLower.includes(queryLower)) score = 40;
            else {
                // Subsequence matching
                var qIdx = 0, tIdx = 0;
                while (qIdx < queryLower.length && tIdx < appNameLower.length) {
                    if (queryLower[qIdx] === appNameLower[tIdx]) qIdx++;
                    tIdx++;
                }
                if (qIdx === queryLower.length) score = 20;
            }

            if (score > 0) {
                // Check if running
                var isRunning = false;
                var clientAddr = "";
                for (var rc = 0; rc < root.runningClients.length; rc++) {
                    var rClient = root.runningClients[rc];
                    if (rClient && rClient.class && appExecLower.includes(rClient.class.toLowerCase())) {
                        isRunning = true;
                        clientAddr = rClient.address;
                        break;
                    }
                }

                appMatches.push({
                    score: score,
                    type: "Applications",
                    name: appItem.name,
                    icon: appItem.iconName,
                    isIconSystem: true,
                    comment: appItem.comment || appItem.exec,
                    exec: appItem.exec,
                    running: isRunning,
                    address: clientAddr,
                    verb: isRunning ? "Switch to" : "Open",
                    execute: function(item) {
                        if (item.running && item.address) {
                            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + item.address]);
                        } else {
                            Quickshell.execDetached(["sh", "-c", item.exec + " &"]);
                        }
                        root.close();
                    }
                });
            }
        }

        appMatches.sort(function(a, b) { return b.score - a.score; });
        for (var m = 0; m < appMatches.length; m++) {
            res.push(appMatches[m]);
            if (res.length >= 8) break;
        }

        // 8. Fallback Shell Command & Web Search if query has no app matches
        if (res.length === 0 && q.length > 0) {
            res.push({
                type: "Run command",
                name: q,
                icon: "terminal",
                isIconMaterial: true,
                comment: "Run '" + q + "' in terminal",
                verb: "Run",
                execute: function() {
                    Quickshell.execDetached(["kitty", "-e", "sh", "-c", q]);
                    root.close();
                }
            });
            res.push({
                type: "Search the web",
                name: "Search Google for \"" + q + "\"",
                icon: "travel_explore",
                isIconMaterial: true,
                comment: "https://www.google.com/search?q=" + encodeURIComponent(q),
                verb: "Search",
                execute: function() {
                    Quickshell.execDetached(["xdg-open", "https://www.google.com/search?q=" + encodeURIComponent(q)]);
                    root.close();
                }
            });
        }

        return res;
    }

    onQueryChanged: {
        root.selectedIndex = 0;
        root.disarmPointerSelection();
        if (root.mathMode || root.query.startsWith("=")) {
            qalcDebounce.pendingExpr = root.query;
            qalcDebounce.restart();
        }
    }

    function executeSelected() {
        var count = root.visibleResults.length;
        if (count === 0) return;
        var item = root.visibleResults[Math.max(0, Math.min(count - 1, root.selectedIndex))];
        if (item && typeof item.execute === "function") {
            item.execute(item);
        }
    }

    function moveSelection(step) {
        var count = root.visibleResults.length;
        if (count === 0) return;
        root.selectedIndex = Math.max(0, Math.min(count - 1, root.selectedIndex + step));
    }

    function handleKey(event) {
        var forward = event.key === Qt.Key_Down || event.key === Qt.Key_Tab
            || (root.browsing && event.key === Qt.Key_Right);
        var backward = event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
            || (root.browsing && event.key === Qt.Key_Left);

        if (forward) {
            root.disarmPointerSelection();
            root.moveSelection(1);
            event.accepted = true;
        } else if (backward) {
            root.disarmPointerSelection();
            root.moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.executeSelected();
            event.accepted = true;
        } else if (root.clipboardMode && event.key === Qt.Key_Delete) {
            var item = root.visibleResults[root.selectedIndex];
            if (item && item.rawValue) {
                Quickshell.execDetached(["sh", "-c", "echo " + JSON.stringify(item.rawValue) + " | cliphist delete"]);
                cliphistProc.running = true;
            }
            event.accepted = true;
        }
    }

    // Window-level Escape Shortcut
    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: {
            if (input.text.length > 0) input.text = "";
            else root.close();
        }
    }

    // Background Click Away to close (only active when spotlight is open)
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.close()
    }

    // ── Floating Iris Spotlight Capsule ──────────────────────────────────────
    Rectangle {
        id: surface
        width: Math.max(480, Math.min(root.width - 32, 640))
        x: (root.width - width) / 2
        y: Math.max(72, Math.round(root.height * 0.2))
        radius: 26
        color: root.colSurface
        border.width: 1
        border.color: root.colHairline
        clip: true

        visible: root.presentation > 0.01
        opacity: root.presentation
        scale: 0.92 + 0.08 * root.presentation

        height: bodyLayout.implicitHeight
        Behavior on height {
            NumberAnimation {
                duration: 140
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
            }
        }

        // Prevent clicks inside capsule from triggering the backdrop click-away
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: bodyLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            // ── 1. Search Bar Field (58px height) ────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 58

                MaterialSymbol {
                    id: searchGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    iconSize: 22
                    color: input.text.length > 0 ? root.accentColor : root.colMuted
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Active Mode Badge Token at the right
                Rectangle {
                    id: modeToken
                    readonly property var activeInfo: {
                        if (root.clipboardMode) return { glyph: "content_paste", label: "Clipboard" };
                        if (root.mathMode || root.query.startsWith("=")) return { glyph: "calculate", label: "Calculator" };
                        if (root.actionMode) return { glyph: "bolt", label: "Actions" };
                        if (root.emojiMode) return { glyph: "mood", label: "Emoji" };
                        if (root.webMode) return { glyph: "travel_explore", label: "Web" };
                        if (root.commandMode) return { glyph: "terminal", label: "Command" };
                        return null;
                    }

                    visible: activeInfo !== null
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    width: tokenRow.implicitWidth + 20
                    radius: 13
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)

                    Row {
                        id: tokenRow
                        anchors.centerIn: parent
                        spacing: 5
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modeToken.activeInfo ? modeToken.activeInfo.glyph : ""
                            iconSize: 14
                            color: root.accentColor
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modeToken.activeInfo ? modeToken.activeInfo.label : ""
                            color: root.accentColor
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            font.family: "Noto Sans"
                        }
                    }
                }

                // Borderless Search Input
                TextInput {
                    id: input
                    anchors.left: searchGlyph.right
                    anchors.leftMargin: 12
                    anchors.right: modeToken.visible ? modeToken.left : parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.query
                    color: root.colText
                    selectionColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                    selectedTextColor: "#ffffff"
                    font.family: "Noto Sans"
                    font.pixelSize: 21
                    font.weight: Font.Normal
                    clip: true
                    focus: true

                    onTextChanged: {
                        if (root.query !== text) root.query = text;
                    }
                    Keys.onPressed: (event) => root.handleKey(event)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text.length === 0
                        text: "Spotlight Search"
                        color: root.colMuted
                        font.family: "Noto Sans"
                        font.pixelSize: input.font.pixelSize
                        font.weight: Font.Normal
                    }
                }
            }

            // Hairline divider
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                visible: browseView.visible || resultsView.visible
                color: root.colHairline
            }

            // ── 2. Empty Query State: Suggestions & Mode Chips ───────────────
            Item {
                id: browseView
                Layout.fillWidth: true
                visible: root.browsing && (root.suggestions.length > 0 || hintsRow.visible)
                implicitHeight: browseColumn.implicitHeight
                implicitWidth: parent ? parent.width : 300

                Column {
                    id: browseColumn
                    width: parent.width
                    spacing: 0

                Text {
                    visible: root.suggestions.length > 0
                    x: 20
                    topPadding: 12
                    bottomPadding: 4
                    text: "Suggestions"
                    color: root.colMuted
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                // Suggestions Apps Row (8 tiles)
                Item {
                    id: tilesContainer
                    visible: root.suggestions.length > 0
                    width: browseColumn.width - 20
                    x: 10
                    implicitHeight: 84
                    readonly property real tileWidth: width / 8

                    // Sliding Selection Pill
                    Rectangle {
                        visible: root.suggestions.length > 0
                        x: Math.min(root.selectedIndex, root.suggestions.length - 1) * tilesContainer.tileWidth
                        width: tilesContainer.tileWidth
                        height: tilesContainer.height
                        radius: 16
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                        Behavior on x {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: root.browsing ? root.suggestions : []
                            Item {
                                id: tileItem
                                required property var modelData
                                required property int index
                                width: tilesContainer.tileWidth
                                height: tilesContainer.height

                                MouseArea {
                                    id: tileArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: root.pointerSelectionArmed ? Qt.PointingHandCursor : Qt.BlankCursor
                                    onPositionChanged: (event) => {
                                        if (root.armPointerSelection(tileArea, event) && root.selectedIndex !== tileItem.index)
                                            root.selectedIndex = tileItem.index;
                                    }
                                    onClicked: {
                                        root.pointerSelectionArmed = true;
                                        root.selectedIndex = tileItem.index;
                                        root.executeSelected();
                                    }
                                }

                                Image {
                                    id: tileIcon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 10
                                    width: 42
                                    height: 42
                                    source: {
                                        var iconStr = tileItem.modelData.iconName || "";
                                        if (iconStr.startsWith("/") || iconStr.startsWith("file://")) return iconStr.startsWith("file://") ? iconStr : "file://" + iconStr;
                                        return Quickshell.iconPath(iconStr, "application-x-executable");
                                    }
                                    sourceSize.width: 42
                                    sourceSize.height: 42
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    scale: tileArea.pressed ? 0.92 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 80 } }
                                }

                                // Running Dot indicator
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: tileIcon.bottom
                                    anchors.topMargin: 3
                                    visible: tileItem.modelData && tileItem.modelData.running ? true : false
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 8
                                    horizontalAlignment: Text.AlignHCenter
                                    text: tileItem.modelData.name
                                    elide: Text.ElideRight
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: root.selectedIndex === tileItem.index ? root.colText : root.colSubtext
                                }
                            }
                        }
                    }
                }

                // Mode Hint Chips Flow Row
                Flow {
                    id: hintsRow
                    width: browseColumn.width - 32
                    x: 16
                    topPadding: 10
                    bottomPadding: 14
                    spacing: 6

                    Repeater {
                        model: [
                            { key: ";", label: "Clipboard" },
                            { key: "=", label: "Calculator" },
                            { key: "/", label: "Actions" },
                            { key: ":", label: "Emoji" },
                            { key: "?", label: "Web" },
                            { key: "$", label: "Command" }
                        ]

                        Rectangle {
                            id: hintPill
                            required property var modelData
                            implicitHeight: 28
                            implicitWidth: hintInnerRow.implicitWidth + 18
                            radius: 14
                            color: hintArea.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.07)
                            Behavior on color { ColorAnimation { duration: 110 } }

                            MouseArea {
                                id: hintArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.query = hintPill.modelData.key;
                                    input.text = hintPill.modelData.key;
                                    input.forceActiveFocus();
                                }
                            }

                            Row {
                                id: hintInnerRow
                                anchors.centerIn: parent
                                spacing: 7

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(height, keyLbl.implicitWidth + 8)
                                    height: 18
                                    radius: 9
                                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, hintArea.containsMouse ? 0.30 : 0.18)
                                    Behavior on color { ColorAnimation { duration: 110 } }

                                    Text {
                                        id: keyLbl
                                        anchors.centerIn: parent
                                        text: hintPill.modelData.key
                                        color: root.accentColor
                                        font.family: "JetBrainsMono Nerd Font, monospace"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: hintPill.modelData.label
                                    color: hintArea.containsMouse ? root.colText : root.colSubtext
                                    font.family: "Noto Sans"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }
            } // browseColumn Column
            } // browseView Item

            // ── 3. Query Results State ───────────────────────────────────────
            Item {
                id: resultsView
                Layout.fillWidth: true
                visible: !root.browsing && root.query.length > 0
                implicitHeight: resultCol.implicitHeight + 16

                // Sliding Highlight Pill
                Rectangle {
                    id: highlightPill
                    readonly property Item targetRow: resRepeater.count > 0 ? resRepeater.itemAt(root.selectedIndex) : null
                    visible: targetRow !== null
                    x: 8
                    width: parent.width - 16
                    y: resultCol.y + (targetRow ? targetRow.y + targetRow.rowY : 0)
                    height: targetRow ? targetRow.rowHeight : 0
                    radius: 14
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20)
                    Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                }

                Column {
                    id: resultCol
                    y: 8
                    width: parent.width

                    // Empty state fallback
                    Item {
                        width: parent.width
                        height: 44
                        visible: root.visibleResults.length === 0
                        Text {
                            anchors.centerIn: parent
                            text: "No results"
                            color: root.colMuted
                            font.family: "Noto Sans"
                            font.pixelSize: 13
                        }
                    }

                    Repeater {
                        id: resRepeater
                        model: root.browsing ? [] : root.visibleResults
                        Column {
                            id: resEntry
                            required property var modelData
                            required property int index
                            readonly property bool topHit: resEntry.index === 0 && !root.clipboardMode
                            readonly property bool mathHit: resEntry.topHit && resEntry.modelData && resEntry.modelData.isMathHit ? true : false
                            readonly property bool clipImage: resEntry.modelData && resEntry.modelData.isClipImage ? true : false
                            readonly property bool selected: root.selectedIndex === resEntry.index
                            readonly property bool showHeader: resEntry.index === 0
                                || (resEntry.modelData && root.visibleResults[resEntry.index - 1] ? resEntry.modelData.type !== root.visibleResults[resEntry.index - 1].type : true)
                            readonly property real rowY: rowArea.y
                            readonly property real rowHeight: rowArea.height
                            width: resultCol.width

                            // Section Header
                            Text {
                                visible: resEntry.showHeader
                                x: 20
                                height: (resEntry.index === 0 ? 24 : 30)
                                verticalAlignment: Text.AlignBottom
                                bottomPadding: 5
                                text: resEntry.index === 0 && !root.clipboardMode ? "Top hit" : String(resEntry.modelData && resEntry.modelData.type ? resEntry.modelData.type : "")
                                color: root.colMuted
                                font.family: "Noto Sans"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            // Result Row
                            MouseArea {
                                id: rowArea
                                x: 8
                                width: parent.width - 16
                                height: resEntry.clipImage ? 68
                                    : (resEntry.mathHit ? 66 : resEntry.topHit ? 58 : 40)
                                hoverEnabled: true
                                cursorShape: root.pointerSelectionArmed ? Qt.PointingHandCursor : Qt.BlankCursor

                                onPositionChanged: (event) => {
                                    if (root.armPointerSelection(rowArea, event) && !resEntry.selected)
                                        root.selectedIndex = resEntry.index;
                                }
                                onClicked: {
                                    root.pointerSelectionArmed = true;
                                    root.selectedIndex = resEntry.index;
                                    root.executeSelected();
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    // Icon Area
                                    Item {
                                        readonly property real iconBoxSize: resEntry.clipImage ? 44 : (resEntry.topHit ? 38 : 24)
                                        Layout.preferredWidth: iconBoxSize
                                        Layout.preferredHeight: iconBoxSize

                                        // System App Icon
                                        Image {
                                            anchors.fill: parent
                                            visible: resEntry.modelData && resEntry.modelData.isIconSystem ? true : false
                                            source: {
                                                var iconStr = resEntry.modelData && resEntry.modelData.icon ? resEntry.modelData.icon : "";
                                                if (iconStr.startsWith("/") || iconStr.startsWith("file://")) return iconStr.startsWith("file://") ? iconStr : "file://" + iconStr;
                                                return Quickshell.iconPath(iconStr, "application-x-executable");
                                            }
                                            sourceSize.width: parent.width
                                            sourceSize.height: parent.height
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }

                                        // Text / Emoji Icon
                                        Text {
                                            anchors.centerIn: parent
                                            visible: resEntry.modelData && resEntry.modelData.isIconText ? true : false
                                            text: resEntry.modelData && resEntry.modelData.icon ? resEntry.modelData.icon : ""
                                            font.pixelSize: resEntry.topHit ? 28 : 18
                                        }

                                        // Material Symbol inside quiet rounded well
                                        Rectangle {
                                            anchors.fill: parent
                                            visible: resEntry.modelData && resEntry.modelData.isIconMaterial ? true : false
                                            radius: width / 2
                                            color: Qt.rgba(1, 1, 1, 0.10)
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: resEntry.modelData && resEntry.modelData.icon ? resEntry.modelData.icon : "search"
                                                iconSize: Math.round(parent.width * 0.58)
                                                color: root.colText
                                            }
                                        }
                                    }

                                    // Title & Comment Column
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            color: root.colText
                                            textFormat: Text.StyledText
                                            text: {
                                                if (resEntry.mathHit) {
                                                    return "<font color='" + root.secondaryAccent + "'>=</font> <font color='" + root.colText + "'>" + root.escapeHtml(resEntry.modelData && resEntry.modelData.name ? resEntry.modelData.name : "") + "</font>";
                                                }
                                                if (resEntry.clipImage) {
                                                    return "<b><font color='" + root.colText + "'>Image</font></b> <font color='" + root.colMuted + "'>" + root.escapeHtml(resEntry.modelData && resEntry.modelData.comment ? resEntry.modelData.comment : "") + "</font>";
                                                }
                                                return root.emphasised(String(resEntry.modelData && resEntry.modelData.name ? resEntry.modelData.name : ""), root.query);
                                            }
                                            font.family: resEntry.mathHit ? "Noto Sans" : "Noto Sans"
                                            font.pixelSize: resEntry.mathHit ? 28 : (resEntry.topHit ? 16 : 14)
                                            font.weight: resEntry.mathHit ? Font.Bold : (resEntry.topHit ? Font.DemiBold : Font.Normal)
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: resEntry.topHit && text.length > 0
                                            text: resEntry.mathHit ? root.query : (resEntry.modelData && resEntry.modelData.comment ? resEntry.modelData.comment : "")
                                            color: root.colSubtext
                                            font.family: "Noto Sans"
                                            font.pixelSize: 12
                                            font.weight: Font.Normal
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Action Verb Label
                                    Text {
                                        visible: resEntry.selected && text.length > 0
                                        text: String(resEntry.modelData && resEntry.modelData.verb ? resEntry.modelData.verb : "")
                                        color: root.colSubtext
                                        font.family: "Noto Sans"
                                        font.pixelSize: 12
                                    }

                                    // Return Keycap Pill [ ↵ ]
                                    Rectangle {
                                        visible: resEntry.selected
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 20
                                        radius: 6
                                        color: Qt.rgba(1, 1, 1, 0.12)
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "keyboard_return"
                                            iconSize: 14
                                            color: root.colText
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
