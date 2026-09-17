import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: launcher
    spacing: 8
    Layout.fillWidth: true
    Layout.fillHeight: true

    property alias searchInput: searchInput
    property var allApps: []
    property var runningClients: []
    property var clipboardEntries: []

    ListModel { id: resultsModel }

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
    readonly property int calculatedCount: resultsModel.count + (hasPowerCard ? 1 : 0)
    readonly property color accentColor: Theme.colors.accent ?? "#7aa2f7"

    // Search prefixes matching Iris
    readonly property string prefixClipboard: ";"
    readonly property string prefixMath: "="
    readonly property string prefixAction: "/"
    readonly property string prefixEmoji: ":"
    readonly property string prefixWeb: "?"
    readonly property string prefixCommand: "$"

    property string rawQuery: searchInput.text.trim()
    readonly property bool browsing: rawQuery.length === 0
    readonly property bool clipboardMode: rawQuery.startsWith(prefixClipboard)
    readonly property bool mathMode: rawQuery.startsWith(prefixMath) || (!rawQuery.startsWith(";") && !rawQuery.startsWith("/") && !rawQuery.startsWith(":") && !rawQuery.startsWith("?") && !rawQuery.startsWith("$") && !rawQuery.startsWith(">") && /[0-9]/.test(rawQuery) && /[\+\-\*\/\%]|sqrt|sin|cos|tan|\^|\bto\b|\bin\b/.test(rawQuery))
    readonly property bool actionMode: rawQuery.startsWith(prefixAction)
    readonly property bool emojiMode: rawQuery.startsWith(prefixEmoji)
    readonly property bool webMode: rawQuery.startsWith(prefixWeb)
    readonly property bool commandMode: rawQuery.startsWith(prefixCommand) || rawQuery.startsWith(">")

    // Caelestia-flavoured emphasized-decelerate curve
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

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
        { emoji: "💀", name: "skull dead dying laugh" },
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
        { name: "Text OCR Capture", cmd: "bash " + (Quickshell.shellDir || Quickshell.configDir) + "/scripts/snip_ocr.sh", icon: "document_scanner", action: "ocr" },
        { name: "Toggle Do Not Disturb", cmd: "notify-send 'DND toggled'", icon: "notifications_off", action: "dnd" },
        { name: "Reload Shell", cmd: "~/.config/quickshell/reload.sh &", icon: "refresh", action: "reload" },
        { name: "Open Terminal", cmd: "kitty", icon: "terminal", action: "terminal" },
        { name: "Open File Manager", cmd: "xdg-open ~", icon: "folder_open", action: "files" }
    ]

    Component.onCompleted: {
        appScanner.running = true;
        clientScanner.running = true;
    }

    function onOpened() {
        launcher.isCopiedFeedback = false;
        clientScanner.running = true;
        if (allApps.length === 0 && !appScanner.running) {
            appScanner.running = true;
        } else {
            launcher.processSearch(searchInput.text);
        }
        searchInput.forceActiveFocus();
        if (resultsModel.count > 0) appList.currentIndex = 0;
    }

    onVisibleChanged: {
        if (visible) {
            onOpened();
        } else {
            launcher.isCopiedFeedback = false;
        }
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
        if (trimmed.startsWith("=")) trimmed = trimmed.substring(1).trim();
        if (trimmed.length < 2) return null;

        var s = trimmed.replace(/,/g, '').replace(/x/gi, '*').trim();
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

    // Hyprland running clients scanner
    Process {
        id: clientScanner
        running: false
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    launcher.runningClients = JSON.parse(this.text) || [];
                } catch(e) {
                    launcher.runningClients = [];
                }
            }
        }
    }

    function getRunningClient(appExec, appName) {
        if (!launcher.runningClients || launcher.runningClients.length === 0) return null;
        var execLower = (appExec || "").toLowerCase();
        var nameLower = (appName || "").toLowerCase();
        for (var i = 0; i < launcher.runningClients.length; i++) {
            var c = launcher.runningClients[i];
            if (!c) continue;
            var cClass = (c.class || "").toLowerCase();
            var cInitial = (c.initialClass || "").toLowerCase();
            if ((cClass && (execLower.includes(cClass) || cClass.includes(nameLower) || nameLower.includes(cClass))) ||
                (cInitial && (execLower.includes(cInitial) || cInitial.includes(nameLower)))) {
                return c;
            }
        }
        return null;
    }

    // Clipboard history scanner for prefix ";"
    Process {
        id: clipScanner
        running: false
        command: ["sh", "-c", "cliphist list | head -n 40"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var items = [];
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim();
                    if (!l) continue;
                    var tabIdx = l.indexOf("\t");
                    var id = tabIdx > 0 ? l.substring(0, tabIdx) : "";
                    var val = tabIdx > 0 ? l.substring(tabIdx + 1) : l;
                    items.push({ "id": id, "text": val, "raw": l });
                }
                launcher.clipboardEntries = items;
                launcher.populateClipboardResults(launcher.rawQuery.substring(1).trim().toLowerCase());
            }
        }
    }

    function populateClipboardResults(query) {
        resultsModel.clear();
        var count = 0;
        for (var i = 0; i < launcher.clipboardEntries.length; i++) {
            var item = launcher.clipboardEntries[i];
            if (query === "" || item.text.toLowerCase().includes(query)) {
                resultsModel.append({
                    itemType: "clip",
                    name: item.text.replace(/[\r\n\t]+/g, " "),
                    comment: "Clipboard #" + item.id,
                    iconName: "",
                    matIcon: "content_paste",
                    nerdIcon: "",
                    execCmd: "",
                    rawVal: item.raw,
                    isRunning: false,
                    winAddress: "",
                    actionVerb: "Copy"
                });
                count++;
                if (count >= 7) break;
            }
        }
        appList.currentIndex = resultsModel.count > 0 ? 0 : -1;
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

    function recordUsageAndLaunch(execCmd) {
        appRunner.command = ["sh", "-c", execCmd + " &"];
        appRunner.running = true;
        usageTracker.targetExec = execCmd;
        usageTracker.running = true;
        root.collapseToIdle();
    }

    // ========================================================
    // MAIN SEARCH DISPATCHER
    // ========================================================
    function processSearch(filterText) {
        var raw = filterText.trim();
        resultsModel.clear();

        // 1. Reset Power States
        launcher.isMathActive = false;
        launcher.isBangActive = false;
        launcher.isCmdActive = false;
        launcher.mathResult = "";
        launcher.mathRawResult = "";

        // 2. EMPTY / BROWSING STATE: Frequently used suggestions
        if (raw === "") {
            var limit = Math.min(launcher.allApps.length, 6);
            for (var s = 0; s < limit; s++) {
                var a = launcher.allApps[s];
                var rc = getRunningClient(a.exec, a.name);
                resultsModel.append({
                    itemType: "app",
                    name: a.name,
                    comment: a.comment || a.exec,
                    iconName: a.iconName,
                    matIcon: "",
                    nerdIcon: "",
                    execCmd: a.exec,
                    rawVal: "",
                    isRunning: rc !== null,
                    winAddress: rc ? rc.address : "",
                    actionVerb: rc !== null ? "Switch to" : "Open"
                });
            }
            appList.currentIndex = resultsModel.count > 0 ? 0 : -1;
            return;
        }

        // 3. CLIPBOARD MODE (";")
        if (raw.startsWith(prefixClipboard)) {
            var cQuery = raw.substring(1).trim().toLowerCase();
            if (launcher.clipboardEntries.length === 0) {
                clipScanner.running = true;
            } else {
                launcher.populateClipboardResults(cQuery);
            }
            return;
        }

        // 4. ACTIONS MODE ("/")
        if (raw.startsWith(prefixAction)) {
            var actQuery = raw.substring(1).trim().toLowerCase();
            for (var k = 0; k < launcher.actionsList.length; k++) {
                var act = launcher.actionsList[k];
                if (actQuery === "" || act.name.toLowerCase().includes(actQuery) || act.action.toLowerCase().includes(actQuery)) {
                    resultsModel.append({
                        itemType: "action",
                        name: act.name,
                        comment: "/" + act.action,
                        iconName: "",
                        matIcon: act.icon,
                        nerdIcon: "",
                        execCmd: act.cmd,
                        rawVal: "",
                        isRunning: false,
                        winAddress: "",
                        actionVerb: "Run"
                    });
                }
            }
            appList.currentIndex = resultsModel.count > 0 ? 0 : -1;
            return;
        }

        // 5. EMOJI MODE (":")
        if (raw.startsWith(prefixEmoji)) {
            var emQuery = raw.substring(1).trim().toLowerCase();
            var emCount = 0;
            for (var em = 0; em < launcher.emojisList.length; em++) {
                var eObj = launcher.emojisList[em];
                if (emQuery === "" || eObj.name.toLowerCase().includes(emQuery)) {
                    resultsModel.append({
                        itemType: "emoji",
                        name: eObj.emoji + "  " + eObj.name,
                        comment: ":" + eObj.name.split(" ")[0],
                        iconName: "",
                        matIcon: "",
                        nerdIcon: eObj.emoji,
                        execCmd: "",
                        rawVal: eObj.emoji,
                        isRunning: false,
                        winAddress: "",
                        actionVerb: "Copy"
                    });
                    emCount++;
                    if (emCount >= 7) break;
                }
            }
            appList.currentIndex = resultsModel.count > 0 ? 0 : -1;
            return;
        }

        // 6. WEB SEARCH MODE ("?")
        if (raw.startsWith(prefixWeb)) {
            var wQuery = raw.substring(1).trim();
            if (wQuery.length > 0) {
                resultsModel.append({
                    itemType: "web",
                    name: "Search Google for \"" + wQuery + "\"",
                    comment: "https://www.google.com/search?q=" + encodeURIComponent(wQuery),
                    iconName: "",
                    matIcon: "travel_explore",
                    nerdIcon: "",
                    execCmd: "https://www.google.com/search?q=" + encodeURIComponent(wQuery),
                    rawVal: "",
                    isRunning: false,
                    winAddress: "",
                    actionVerb: "Search"
                });
            }
            appList.currentIndex = 0;
            return;
        }

        // 7. SHELL COMMAND MODE (">" or "$")
        if (raw.startsWith(">") || raw.startsWith("$")) {
            var cmd = raw.substring(1).trim();
            if (cmd.length > 0) {
                launcher.isCmdActive = true;
                launcher.cmdText = cmd;
                launcher.isCmdInteractive = launcher.isInteractiveTool(cmd);
                return;
            }
        }

        // 8. BANGS ("!")
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
                return;
            }
        }

        // 9. INLINE MATH EVALUATION
        var mathRes = launcher.safeMathEval(raw);
        if (mathRes !== null) {
            launcher.isMathActive = true;
            launcher.mathExpr = raw;
            launcher.mathResult = mathRes.formatted;
            launcher.mathRawResult = mathRes.raw;
        } else if (/\d+\s*[a-zA-Z]+\s+(to|in)\s+[a-zA-Z]+/i.test(raw)) {
            launcher.mathExpr = raw;
            unitCalcDebounce.pendingQuery = raw;
            unitCalcDebounce.restart();
        }

        // 10. DESKTOP APPLICATIONS (Subsequence / Fuzzy / Usage ranking)
        var query = raw.toLowerCase();
        var appMatches = [];
        for (var i = 0; i < launcher.allApps.length; i++) {
            var app = launcher.allApps[i];
            var appNameLower = app.name.toLowerCase();
            var appExecLower = app.exec.toLowerCase();

            var score = -1;
            if (appNameLower === query) score = 100;
            else if (appNameLower.startsWith(query)) score = 80;
            else if (appNameLower.includes(query)) score = 60;
            else if (appExecLower.startsWith(query)) score = 50;
            else if (appExecLower.includes(query)) score = 40;
            else if (launcher.isSubsequence(query, appNameLower)) score = 20;

            if (score > 0) {
                var rcClient = getRunningClient(app.exec, app.name);
                appMatches.push({
                    score: score,
                    app: app,
                    rc: rcClient
                });
            }
        }

        appMatches.sort(function(a, b) { return b.score - a.score; });
        var appLimit = Math.min(appMatches.length, 7);
        for (var m = 0; m < appLimit; m++) {
            var match = appMatches[m];
            resultsModel.append({
                itemType: "app",
                name: match.app.name,
                comment: match.app.comment || match.app.exec,
                iconName: match.app.iconName,
                matIcon: "",
                nerdIcon: "",
                execCmd: match.app.exec,
                rawVal: "",
                isRunning: match.rc !== null,
                winAddress: match.rc ? match.rc.address : "",
                actionVerb: match.rc !== null ? "Switch to" : "Open"
            });
        }

        // 11. FALLBACK WEB SEARCH / SHELL CMD if no apps match
        if (resultsModel.count === 0 && !launcher.hasPowerCard && raw.length > 0) {
            resultsModel.append({
                itemType: "web",
                name: "Search Google for \"" + raw + "\"",
                comment: "https://www.google.com/search?q=" + encodeURIComponent(raw),
                iconName: "",
                matIcon: "travel_explore",
                nerdIcon: "",
                execCmd: "https://www.google.com/search?q=" + encodeURIComponent(raw),
                rawVal: "",
                isRunning: false,
                winAddress: "",
                actionVerb: "Search"
            });
            resultsModel.append({
                itemType: "action",
                name: "Run \"" + raw + "\" in terminal",
                comment: "Execute in Kitty",
                iconName: "",
                matIcon: "terminal",
                nerdIcon: "",
                execCmd: "kitty -e sh -c '" + raw.replace(/'/g, "'\\''") + "'",
                rawVal: "",
                isRunning: false,
                winAddress: "",
                actionVerb: "Run"
            });
        }

        appList.currentIndex = resultsModel.count > 0 ? 0 : -1;
        appList.positionViewAtBeginning();
    }

    function copyMathResult() {
        var toCopy = launcher.mathRawResult || launcher.mathResult;
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(toCopy) + " | wl-copy"]);
        launcher.isCopiedFeedback = true;
        Qt.callLater(() => { copyHideTimer.restart(); });
    }

    Timer {
        id: copyHideTimer
        interval: 350
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

    function executeSelectedItem(idx) {
        if (idx < 0 || idx >= resultsModel.count) return;
        var item = resultsModel.get(idx);

        if (item.itemType === "app") {
            if (item.isRunning && item.winAddress !== "") {
                Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + item.winAddress]);
                root.collapseToIdle();
            } else {
                launcher.recordUsageAndLaunch(item.execCmd);
            }
        } else if (item.itemType === "action") {
            Quickshell.execDetached(["sh", "-c", item.execCmd + " &"]);
            root.collapseToIdle();
        } else if (item.itemType === "clip") {
            Quickshell.execDetached(["sh", "-c", "echo " + JSON.stringify(item.rawVal) + " | cliphist decode | wl-copy"]);
            root.collapseToIdle();
        } else if (item.itemType === "emoji") {
            Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(item.rawVal) + " | wl-copy"]);
            root.collapseToIdle();
        } else if (item.itemType === "web") {
            Quickshell.execDetached(["xdg-open", item.execCmd]);
            root.collapseToIdle();
        }
    }

    // ========================================================
    // 1. SEARCH BAR (INSIDE THE NOTCH)
    // ========================================================
    Rectangle {
        id: searchBar
        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: 14
        color: Theme.colors.card_bg ?? "#1f2335"
        border.width: 1.5
        border.color: searchInput.activeFocus ? launcher.accentColor : Qt.rgba(1, 1, 1, 0.08)
        Behavior on border.color { ColorAnimation { duration: 180 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 10

            // Dynamic Prefix / Search Glyph
            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter

                MaterialSymbol {
                    anchors.centerIn: parent
                    iconSize: 20
                    visible: launcher.clipboardMode || launcher.actionMode || launcher.webMode || (!launcher.isMathActive && !launcher.isCmdActive && !launcher.isBangActive && !launcher.emojiMode)
                    text: {
                        if (launcher.clipboardMode) return "content_paste";
                        if (launcher.actionMode) return "bolt";
                        if (launcher.webMode) return "travel_explore";
                        return "search";
                    }
                    color: searchInput.activeFocus ? launcher.accentColor : (Theme.colors.text_secondary ?? "#a9b1d6")
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                Text {
                    anchors.centerIn: parent
                    visible: launcher.isMathActive || launcher.isCmdActive || launcher.isBangActive || launcher.emojiMode
                    text: {
                        if (launcher.isMathActive) return "󱖦";
                        if (launcher.isCmdActive) return "󰞷";
                        if (launcher.isBangActive) return launcher.bangIcon || "󰊭";
                        if (launcher.emojiMode) return "󰞅";
                        return "⌕";
                    }
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 17
                    color: searchInput.activeFocus ? launcher.accentColor : (Theme.colors.text_secondary ?? "#a9b1d6")
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }

            // Input Field
            TextField {
                id: searchInput
                focus: true
                selectByMouse: true
                Layout.fillWidth: true
                color: Theme.colors.text_primary ?? "#c0caf5"
                font.family: "Noto Sans"
                font.pixelSize: 14
                placeholderText: "Search apps, math (=), actions (/), clipboard (;), emoji (:)..."
                placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                background: Item {}

                onTextChanged: launcher.processSearch(text)

                Keys.onDownPressed: (event) => {
                    if (appList.currentIndex < resultsModel.count - 1) {
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
                Keys.onEscapePressed: root.collapseToIdle()

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
                    } else if (resultsModel.count > 0 && appList.currentIndex >= 0) {
                        launcher.executeSelectedItem(appList.currentIndex);
                        event.accepted = true;
                    } else if (text.trim() !== "") {
                        appRunner.command = ["sh", "-c", text.trim() + " &"];
                        appRunner.running = true;
                        root.collapseToIdle();
                        event.accepted = true;
                    }
                }
            }

            // Active Mode Token Pill
            Rectangle {
                id: activeModeToken
                readonly property var activeInfo: {
                    if (launcher.clipboardMode) return { glyph: "content_paste", label: "Clipboard" };
                    if (launcher.mathMode) return { glyph: "calculate", label: "Calculator" };
                    if (launcher.actionMode) return { glyph: "bolt", label: "Actions" };
                    if (launcher.emojiMode) return { glyph: "mood", label: "Emoji" };
                    if (launcher.webMode) return { glyph: "travel_explore", label: "Web" };
                    if (launcher.commandMode) return { glyph: "terminal", label: "Shell" };
                    return null;
                }

                visible: activeInfo !== null && searchInput.text.trim().length > 1
                Layout.preferredHeight: 24
                Layout.preferredWidth: modeRow.implicitWidth + 14
                radius: 12
                color: Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.2)

                Row {
                    id: modeRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: activeModeToken.activeInfo ? activeModeToken.activeInfo.glyph : ""
                        iconSize: 13
                        color: launcher.accentColor
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: activeModeToken.activeInfo ? activeModeToken.activeInfo.label : ""
                        color: launcher.accentColor
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.family: "Noto Sans"
                    }
                }
            }

            // Clear Button
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
    // 2. EMPTY STATE: MODE HINT CHIPS ROW
    // ========================================================
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: -2
        Layout.bottomMargin: 2
        spacing: 5
        visible: launcher.browsing

        component HintChip: Rectangle {
            id: chipRoot
            property string prefixChar: ""
            property string labelText: ""
            property string iconName: ""
            Layout.fillWidth: true
            height: 26
            radius: 8
            color: chipMouse.containsMouse ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.16) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: chipMouse.containsMouse ? launcher.accentColor : Qt.rgba(1, 1, 1, 0.06)
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 3
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chipRoot.prefixChar
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: launcher.accentColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chipRoot.labelText
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: chipMouse.containsMouse ? (Theme.colors.text_primary ?? "#c0caf5") : (Theme.colors.text_secondary ?? "#8a8f9e")
                }
            }

            MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    searchInput.text = chipRoot.prefixChar + " ";
                    searchInput.cursorPosition = searchInput.text.length;
                    searchInput.forceActiveFocus();
                }
            }
        }

        HintChip { prefixChar: ";"; labelText: "Clip" }
        HintChip { prefixChar: "="; labelText: "Math" }
        HintChip { prefixChar: "/"; labelText: "Action" }
        HintChip { prefixChar: ":"; labelText: "Emoji" }
        HintChip { prefixChar: "?"; labelText: "Web" }
        HintChip { prefixChar: ">"; labelText: "Shell" }
    }

    // ========================================================
    // 3. POWER USER CARDS (Math / Bang / Shell Command)
    // ========================================================
    // Math Evaluation Card
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

                Text {
                    text: "= " + launcher.mathResult
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                    color: launcher.isCopiedFeedback ? "#73daca" : (Theme.colors.text_primary ?? "#c0caf5")
                }

                Text {
                    text: launcher.isCopiedFeedback ? "Copied answer to clipboard!" : (launcher.mathExpr + " · Press Enter to copy")
                    font.family: "Noto Sans"
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
                    text: launcher.isCopiedFeedback ? "Copied" : "Copy ↵"
                    font.family: "Noto Sans"
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

    // Search Bang Card
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
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.colors.text_primary ?? "#c0caf5"
                    elide: Text.ElideRight
                }

                Text {
                    text: (launcher.bangType === "keys" || launcher.bangType === "notes") ? "Press Enter to open module" : "Press Enter to search in default browser"
                    font.family: "Noto Sans"
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
                    font.family: "Noto Sans"
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

    // Shell Command Card (">" or "$")
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
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            color: launcher.isCmdInteractive ? launcher.accentColor : (Theme.colors.text_secondary ?? "#565f89")
                        }
                    }
                }

                Text {
                    text: "Press Enter to execute · Shift+Enter to force in Kitty terminal"
                    font.family: "Noto Sans"
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
                    font.family: "Noto Sans"
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
    // 4. RESULTS HEADER & LIST VIEW
    // ========================================================
    Text {
        Layout.leftMargin: 4
        visible: !launcher.isBangActive && !launcher.isCmdActive && resultsModel.count > 0
        text: {
            if (launcher.browsing) return "Frequently Used";
            if (launcher.clipboardMode) return "Clipboard History (" + resultsModel.count + ")";
            if (launcher.actionMode) return "System Actions (" + resultsModel.count + ")";
            if (launcher.emojiMode) return "Emoji Results (" + resultsModel.count + ")";
            if (launcher.webMode) return "Web Search";
            return resultsModel.count + (resultsModel.count === 1 ? " result" : " results");
        }
        font.family: "Noto Sans"
        font.pixelSize: 11
        font.weight: Font.DemiBold
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
            model: resultsModel
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

            boundsBehavior: Flickable.DragAndOvershootBounds
            maximumFlickVelocity: 3500
            flickDeceleration: 2200

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
                height: 44
                property bool isSelected: ListView.isCurrentItem
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
                    spacing: 10

                    // Icon Container
                    Rectangle {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        radius: 9
                        color: delegateRoot.isSelected
                            ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.24)
                            : Qt.rgba(1, 1, 1, 0.05)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        // 1. Material Icon
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: model.matIcon !== ""
                            text: model.matIcon
                            iconSize: 18
                            color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_primary ?? "#c0caf5")
                        }

                        // 2. Nerd Icon / Text
                        Text {
                            anchors.centerIn: parent
                            visible: model.nerdIcon !== "" && model.matIcon === ""
                            text: model.nerdIcon
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 17
                            color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_primary ?? "#c0caf5")
                        }

                        // 3. Fallback App Icon
                        Item {
                            anchors.fill: parent
                            visible: model.matIcon === "" && model.nerdIcon === "" && !appIcon.visible

                            Text {
                                anchors.centerIn: parent
                                text: "󰀻"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_secondary ?? "#565f89")
                            }
                        }

                        // 4. Desktop File Icon Image
                        Image {
                            id: appIcon
                            anchors.fill: parent
                            anchors.margins: 4
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 28
                            sourceSize.height: 28
                            visible: model.matIcon === "" && model.nerdIcon === "" && status === Image.Ready && source != ""
                            
                            source: {
                                if (!model.iconName || model.iconName === "") return "";
                                if (model.iconName.startsWith("/")) return "file://" + model.iconName;
                                return "image://icon/" + model.iconName;
                            }
                        }
                    }

                    // Title & Description Column
                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: model.name
                            color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_primary ?? "#c0caf5")
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: model.comment
                            color: delegateRoot.isSelected ? (Theme.colors.text_primary ?? "#a9b1d6") : (Theme.colors.text_secondary ?? "#565f89")
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }

                    // Running Badge Pill (if window is active)
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        visible: model.isRunning
                        height: 18
                        width: runRow.implicitWidth + 10
                        radius: 9
                        color: Qt.rgba(0.2, 0.8, 0.4, 0.18)

                        Row {
                            id: runRow
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: "#73daca"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Running"
                                font.family: "Noto Sans"
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: "#73daca"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Action Hint Pill
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        height: 20
                        width: actionHintText.implicitWidth + 12
                        radius: 6
                        color: delegateRoot.isSelected ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                        visible: delegateRoot.isSelected || model.isRunning

                        Text {
                            id: actionHintText
                            anchors.centerIn: parent
                            text: model.actionVerb + " ↵"
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_secondary ?? "#8a8f9e")
                        }
                    }
                }

                MouseArea {
                    id: appMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: appList.currentIndex = index
                    onClicked: launcher.executeSelectedItem(index)
                }
            }
        }

        // Empty state when search yields no results
        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: resultsModel.count === 0 && searchInput.text.trim() !== "" && !launcher.isMathActive && !launcher.isCmdActive && !launcher.isBangActive

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰍉"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 22
                color: Theme.colors.text_secondary ?? "#565f89"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No results found"
                font.family: "Noto Sans"
                font.pixelSize: 12
                color: Theme.colors.text_secondary ?? "#565f89"
            }
        }
    }
}