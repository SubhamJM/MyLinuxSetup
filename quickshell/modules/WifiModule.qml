import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: wifiMaster
    spacing: 10

    property string activeTab: "wifi"
    property bool wifiEnabled: true
    property bool hotspotActive: false
    property string activeWifiSsid: ""
    property real listViewContentHeight: wifiListView.contentHeight
    property bool isScanning: false
    property var savedConnections: ({})
    property string connectingSsid: ""
    readonly property bool isConnected: (typeof dashMod !== "undefined" && dashMod.activeNetName !== "")

    // Live Network Interface & IP Metadata
    property string netDev: ""
    property string netIp: ""
    property string netGw: ""
    property string netSpeed: ""
    property string netWarp: ""

    property string hotspotSsid: "SubhamLaptop"
    property string hotspotPass: "000000001"
    property bool hotspotShowPassword: false

    // Material 3 Expressive (Android 17) Tokens — solid tonal surfaces, no borders
    readonly property color colSurface: "#000000"
    readonly property color colCard: Theme.colors.card_bg ?? "#181c24"
    readonly property color colCardHover: Theme.colors.hover_bg ?? "#222834"
    readonly property color colCardActive: Qt.alpha(wifiMaster.colAccent, 0.20)
    readonly property color colChipBg: Theme.colors.hover_bg ?? "#222834"
    readonly property color colText: Theme.colors.text_primary ?? "#eceff4"
    readonly property color colSubtext: Theme.colors.text_secondary ?? "#d8dee9"
    readonly property color colMuted: Theme.colors.text_muted ?? "#81a1c1"
    readonly property color colAccent: Theme.colors.accent ?? "#88c0d0"
    readonly property color colGreen: ({ nord: "#a3be8c", dracula: "#50fa7b", catppuccin: "#a6e3a1", everforest: "#a7c080", "rose-pine": "#9ccfd8" })[Theme.currentThemeName] ?? "#30d158"
    readonly property color colRed: ({ nord: "#bf616a", dracula: "#ff5555", catppuccin: "#f38ba8", everforest: "#e67e80", "rose-pine": "#eb6f92" })[Theme.currentThemeName] ?? "#ff453a"
    readonly property color colYellow: "#ebcb8b"

    readonly property alias model: wifiModel

    function isAnyWifiExpanded() {
        if (connectingSsid !== "") return true;
        for (var i = 0; i < wifiModel.count; i++) {
            if (wifiModel.get(i).isExpanded) return true;
        }
        return false;
    }

    ListModel { id: wifiModel }

    // ------------------------------------------------------------------
    // Sort helper: connected first, then saved, then strongest signal.
    // Fixes "connected network not shown at top" bug.
    // ------------------------------------------------------------------
    function sortWifiModel() {
        var items = [];
        for (var i = 0; i < wifiModel.count; i++) items.push(wifiModel.get(i));

        items.sort(function(a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
            if (a.isSaved !== b.isSaved) return a.isSaved ? -1 : 1;
            return b.signal - a.signal;
        });

        var alreadySorted = true;
        for (var k = 0; k < items.length; k++) {
            if (wifiModel.get(k).ssid !== items[k].ssid) { alreadySorted = false; break; }
        }
        if (alreadySorted) return;

        var snapshot = items.map(function(o) {
            return {
                "inUse": o.inUse, "ssid": o.ssid, "signal": o.signal, "security": o.security,
                "band": o.band, "rate": o.rate, "isSaved": o.isSaved, "isExpanded": o.isExpanded,
                "showPassword": o.showPassword, "hasError": o.hasError, "errorMsg": o.errorMsg
            };
        });
        wifiModel.clear();
        for (var j = 0; j < snapshot.length; j++) wifiModel.append(snapshot[j]);
    }

    // Fast network metadata reader
    Process {
        id: netInfoChecker
        running: false
        command: [
            "sh", "-c",
            'DEV=$(ip route show default 2>/dev/null | awk "{print \\$5; exit}"); ' +
            'GW=$(ip route show default 2>/dev/null | awk "{print \\$3; exit}"); ' +
            'IP=$(ip -4 -br a show dev "$DEV" 2>/dev/null | awk "{print \\$3}" | cut -d/ -f1); ' +
            'SPEED=$(cat /sys/class/net/"$DEV"/speed 2>/dev/null); ' +
            '[ -n "$SPEED" ] && SPEED="${SPEED} Mbps" || SPEED=""; ' +
            'WARP=$(ip -4 -br a show dev CloudflareWARP 2>/dev/null | awk "{print \\$3}" | cut -d/ -f1); ' +
            'echo "$DEV|$IP|$GW|$SPEED|$WARP"'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|");
                if (parts.length >= 5) {
                    wifiMaster.netDev = parts[0];
                    wifiMaster.netIp = parts[1];
                    wifiMaster.netGw = parts[2];
                    wifiMaster.netSpeed = parts[3];
                    wifiMaster.netWarp = parts[4];
                }
            }
        }
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
                wifiMaster.savedConnections = map;
                wifiScanner.running = true;
            }
        }
    }

    Process {
        id: wifiScanner
        command: [
            "sh", "-c", 
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,CHAN,FREQ,RATE dev wifi list --rescan no 2>/dev/null | awk -F':' '{ if ($2 != \"\" && $2 != \"--\") { in_use=($1==\"*\")?1:0; print in_use \"|||\" $2 \"|||\" $3 \"|||\" $4 \"|||\" $5 \"|||\" $6 \"|||\" $7 } }'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var fresh = {};
                var order = [];
                var foundActive = "";

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    var parts = line.split("|||");
                    if (parts.length >= 7) {
                        var isConn = (parts[0] === "1");
                        var ssidName = parts[1].replace(/\\:/g, ":").trim();
                        var sig = parseInt(parts[2]) || 0;
                        var sec = parts[3].trim();
                        var chan = parseInt(parts[4]) || 0;
                        var freqStr = parts[5].trim();
                        var rateStr = parts[6].trim().replace("Mbit/s", "Mbps");
                        var bandStr = (freqStr.indexOf("5") === 0 || chan > 14) ? "5 GHz" : "2.4 GHz";

                        if (ssidName === "" || ssidName === "--") continue;
                        if (isConn) foundActive = ssidName;

                        if (!fresh[ssidName] || isConn || sig > fresh[ssidName].signal) {
                            if (!fresh[ssidName]) order.push(ssidName);
                            fresh[ssidName] = {
                                "inUse": isConn,
                                "ssid": ssidName,
                                "signal": sig,
                                "security": sec,
                                "band": bandStr,
                                "rate": rateStr,
                                "isSaved": !!wifiMaster.savedConnections[ssidName]
                            };
                        }
                    }
                }

                // Sort discovery order too: connected first, then saved, then signal.
                // Fixes "connected network not shown at top" bug.
                order.sort(function(a, b) {
                    var ia = fresh[a], ib = fresh[b];
                    if (ia.inUse !== ib.inUse) return ia.inUse ? -1 : 1;
                    if (ia.isSaved !== ib.isSaved) return ia.isSaved ? -1 : 1;
                    return ib.signal - ia.signal;
                });

                var existingMap = {};
                for (var e = 0; e < wifiModel.count; e++) {
                    existingMap[wifiModel.get(e).ssid] = e;
                }

                for (var idx = wifiModel.count - 1; idx >= 0; idx--) {
                    var row = wifiModel.get(idx);
                    if (!fresh[row.ssid]) {
                        if (!row.isExpanded && wifiMaster.connectingSsid !== row.ssid) {
                            wifiModel.remove(idx);
                        }
                    } else {
                        var upd = fresh[row.ssid];
                        if (row.inUse !== upd.inUse) wifiModel.setProperty(idx, "inUse", upd.inUse);
                        if (row.signal !== upd.signal) wifiModel.setProperty(idx, "signal", upd.signal);
                        if (row.security !== upd.security) wifiModel.setProperty(idx, "security", upd.security);
                        if (row.band !== upd.band) wifiModel.setProperty(idx, "band", upd.band);
                        if (row.rate !== upd.rate) wifiModel.setProperty(idx, "rate", upd.rate);
                        if (row.isSaved !== upd.isSaved) wifiModel.setProperty(idx, "isSaved", upd.isSaved);
                    }
                }

                existingMap = {};
                for (var m = 0; m < wifiModel.count; m++) {
                    existingMap[wifiModel.get(m).ssid] = true;
                }

                for (var o = 0; o < order.length; o++) {
                    var sName = order[o];
                    if (!existingMap[sName]) {
                        var itm = fresh[sName];
                        wifiModel.append({
                            "inUse": itm.inUse,
                            "ssid": itm.ssid,
                            "signal": itm.signal,
                            "security": itm.security,
                            "band": itm.band,
                            "rate": itm.rate,
                            "isSaved": itm.isSaved,
                            "isExpanded": false,
                            "showPassword": false,
                            "hasError": false,
                            "errorMsg": ""
                        });
                    }
                }

                wifiMaster.activeWifiSsid = foundActive;
                wifiMaster.isScanning = false;

                // Re-sort so the connected card is always row 0 — this is what
                // actually guarantees it renders at the top of the ListView.
                wifiMaster.sortWifiModel();
            }
        }
    }

    Process {
        id: wifiRescanTrigger
        running: false
        command: ["sh", "-c", "nmcli dev wifi rescan 2>/dev/null || true"]
        onExited: wifiSavedChecker.running = true
    }

    function triggerScan() {
        wifiMaster.isScanning = true;
        wifiRescanTrigger.running = true;
    }

    Process { 
        id: wifiConnector
        running: false
        property string targetSsid: ""
        stdout: StdioCollector { id: connectOutCollector }
        stderr: StdioCollector { id: connectErrCollector }

        onExited: (exitCode) => {
            var out = (connectOutCollector.text + " " + connectErrCollector.text).toLowerCase();
            var fail = exitCode !== 0 || out.includes("error") || out.includes("secrets were required") || out.includes("failed");

            if (fail) {
                Quickshell.execDetached(["nmcli", "connection", "delete", "id", targetSsid]);
                for (var i = 0; i < wifiModel.count; i++) {
                    if (wifiModel.get(i).ssid === targetSsid) {
                        wifiModel.setProperty(i, "hasError", true);
                        wifiModel.setProperty(i, "errorMsg", "Incorrect password or connection failed.");
                        wifiModel.setProperty(i, "isExpanded", true);
                        wifiModel.setProperty(i, "showPassword", true);
                        wifiModel.setProperty(i, "isSaved", false);
                        break;
                    }
                }
            } else {
                for (var j = 0; j < wifiModel.count; j++) {
                    if (wifiModel.get(j).ssid === targetSsid) {
                        wifiModel.setProperty(j, "hasError", false);
                        wifiModel.setProperty(j, "errorMsg", "");
                        wifiModel.setProperty(j, "isExpanded", false);
                        wifiModel.setProperty(j, "showPassword", false);
                        wifiModel.setProperty(j, "isSaved", true);
                        break;
                    }
                }
            }
            wifiMaster.connectingSsid = "";
            wifiSavedChecker.running = true;
            netInfoChecker.running = true;
        }
    }

    function initiateConnection(ssid, password, idx) {
        wifiMaster.connectingSsid = ssid;
        wifiModel.setProperty(idx, "hasError", false);
        wifiModel.setProperty(idx, "errorMsg", "");
        wifiConnector.targetSsid = ssid;

        var safeSsid = ssid.replace(/'/g, "'\\x27'");
        var cmd = (password && password.length > 0)
            ? "nmcli dev wifi connect '" + safeSsid + "' password '" + password.replace(/'/g, "'\\x27'") + "'"
            : "nmcli connection up id '" + safeSsid + "' 2>/dev/null || nmcli dev wifi connect '" + safeSsid + "'";

        wifiConnector.command = ["sh", "-c", cmd];
        wifiConnector.running = true;
    }

    Process { id: wifiDisconnecter; running: false; onExited: { wifiSavedChecker.running = true; netInfoChecker.running = true; } }
    Process { id: wifiForgetRunner; running: false; onExited: wifiSavedChecker.running = true }
    Process { id: wifiTrustRunner; running: false; onExited: wifiSavedChecker.running = true }

    Process {
        id: wifiStatusChecker
        command: ["sh", "-c", "nmcli radio wifi"]
        stdout: StdioCollector {
            onStreamFinished: wifiMaster.wifiEnabled = (this.text.trim() === "enabled")
        }
    }

    Process {
        id: wifiToggler
        running: false
        onExited: {
            wifiStatusChecker.running = true;
            wifiSavedChecker.running = true;
            netInfoChecker.running = true;
        }
    }

    Process {
        id: hotspotStatusChecker
        command: ["sh", "-c", "nmcli -t -f TYPE,NAME con show --active | grep -E '^802-11-wireless.*:Hotspot|^wifi.*:Hotspot' || true"]
        stdout: StdioCollector {
            onStreamFinished: wifiMaster.hotspotActive = (this.text.trim().length > 0)
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
            var safeSsid = hotspotSsid.replace(/'/g, "'\\x27'");
            var safePass = hotspotPass.replace(/'/g, "'\\x27'");
            var cmd = "nmcli radio wifi on && sleep 0.5 && nmcli device wifi hotspot ssid '" + safeSsid + "' password '" + safePass + "'";
            hotspotRunner.command = ["sh", "-c", cmd];
            hotspotRunner.running = true;
        } else {
            hotspotRunner.command = ["sh", "-c", "nmcli connection down Hotspot || nmcli connection down id '" + hotspotSsid.replace(/'/g, "'\\x27'") + "' || true"];
            hotspotRunner.running = true;
        }
    }

    function refreshStatus() {
        wifiStatusChecker.running = true;
        wifiSavedChecker.running = true;
        hotspotStatusChecker.running = true;
        netInfoChecker.running = true;
    }

    Timer {
        interval: 4000; running: root.activeMode === "wifi"; repeat: true
        onTriggered: {
            if (!wifiMaster.isScanning && !wifiMaster.isAnyWifiExpanded()) wifiSavedChecker.running = true;
            hotspotStatusChecker.running = true;
            netInfoChecker.running = true;
        }
    }

    Component.onCompleted: refreshStatus()

    // ========================================================
    // 1. HERO CONNECTIVITY CARD — Material 3 Expressive
    // ========================================================
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 92
        radius: 28
        color: wifiMaster.colCard

        Behavior on color { ColorAnimation { duration: 200 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // Top Row: Icon + Names + Online Pill
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Expressive squircle icon badge
                Rectangle {
                    width: 42; height: 42; radius: 16
                    color: wifiMaster.isConnected ? Qt.alpha(wifiMaster.colAccent, 0.22) : wifiMaster.colChipBg
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 22
                        fill: wifiMaster.isConnected ? 1 : 0
                        text: (typeof dashMod !== "undefined" && dashMod.activeNetType === "eth") ? "lan" :
                              (wifiMaster.isConnected ? "wifi" : "wifi_off")
                        color: wifiMaster.isConnected ? wifiMaster.colAccent : wifiMaster.colMuted
                    }
                }

                // Connection Name & Speed
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (typeof dashMod === "undefined") return "Network status";
                            if (dashMod.activeNetName === "") return dashMod.activeNetType === "eth" ? "Ethernet disconnected" : "Wi-Fi disconnected";
                            return dashMod.activeNetName;
                        }
                        font.family: "Noto Sans"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: wifiMaster.colText
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (typeof dashMod === "undefined" || dashMod.activeNetName === "") return "No network connection";
                            var typeStr = dashMod.activeNetType === "eth" ? "Wired Ethernet" : "Wi-Fi";
                            var speedStr = wifiMaster.netSpeed !== "" ? (" • " + wifiMaster.netSpeed) : "";
                            return typeStr + speedStr;
                        }
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: wifiMaster.colSubtext
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                // Aurora Green Online Capsule Pill
                Rectangle {
                    visible: wifiMaster.isConnected
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: statusRow.implicitWidth + 18
                    radius: 13
                    color: Qt.alpha(wifiMaster.colGreen, 0.20)

                    RowLayout {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: wifiMaster.colGreen

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.6; to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.0; to: 0.6; duration: 1000; easing.type: Easing.InOutSine }
                            }
                        }

                        Text {
                            text: "ONLINE"
                            font.family: "Rubik"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.5
                            color: wifiMaster.colGreen
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            // Bottom Row: Chips
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // IPv4 Address Chip
                Rectangle {
                    visible: wifiMaster.netIp !== ""
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: ipChipRow.implicitWidth + 14
                    radius: 8
                    color: wifiMaster.colChipBg

                    RowLayout {
                        id: ipChipRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            iconSize: 12
                            text: "public"
                            color: wifiMaster.colMuted
                        }

                        Text {
                            text: wifiMaster.netIp
                            font.family: "Rubik"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: wifiMaster.colSubtext
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // Interface Device Chip
                Rectangle {
                    visible: wifiMaster.netDev !== ""
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: devChipRow.implicitWidth + 14
                    radius: 8
                    color: wifiMaster.colChipBg

                    RowLayout {
                        id: devChipRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            iconSize: 12
                            text: "developer_board"
                            color: wifiMaster.colMuted
                        }

                        Text {
                            text: wifiMaster.netDev
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: wifiMaster.colSubtext
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // Cloudflare WARP / Gateway Chip
                Rectangle {
                    visible: wifiMaster.netWarp !== "" || wifiMaster.netGw !== ""
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: secChipRow.implicitWidth + 14
                    radius: 8
                    color: wifiMaster.colChipBg

                    RowLayout {
                        id: secChipRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            iconSize: 12
                            text: wifiMaster.netWarp !== "" ? "security" : "router"
                            color: wifiMaster.netWarp !== "" ? wifiMaster.colAccent : wifiMaster.colMuted
                        }

                        Text {
                            text: wifiMaster.netWarp !== "" ? "WARP Active" : ("GW: " + wifiMaster.netGw)
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: wifiMaster.netWarp !== "" ? wifiMaster.colAccent : wifiMaster.colSubtext
                            renderType: Text.NativeRendering
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // ========================================================
    // 2. SEGMENTED BUTTONS — Material 3 Expressive
    // ========================================================
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        radius: 22
        color: wifiMaster.colCard

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            // Wi-Fi Segment
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 18
                color: wifiMaster.activeTab === "wifi" ? wifiMaster.colChipBg : "transparent"
                Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.centerIn: parent; spacing: 6
                    MaterialSymbol {
                        iconSize: 17
                        fill: wifiMaster.activeTab === "wifi" ? 1 : 0
                        text: "wifi"
                        color: wifiMaster.activeTab === "wifi" ? wifiMaster.colAccent : wifiMaster.colMuted
                    }
                    Text {
                        text: "Wi-Fi Networks"
                        font.family: "Noto Sans"
                        font.weight: wifiMaster.activeTab === "wifi" ? Font.DemiBold : Font.Medium
                        font.pixelSize: 12
                        color: wifiMaster.activeTab === "wifi" ? wifiMaster.colText : wifiMaster.colSubtext
                        renderType: Text.NativeRendering
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiMaster.activeTab = "wifi" }
            }

            // Hotspot Segment
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 18
                color: wifiMaster.activeTab === "hotspot" ? wifiMaster.colChipBg : "transparent"
                Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.centerIn: parent; spacing: 6
                    MaterialSymbol {
                        iconSize: 17
                        fill: wifiMaster.activeTab === "hotspot" ? 1 : 0
                        text: "wifi_tethering"
                        color: wifiMaster.activeTab === "hotspot" ? wifiMaster.colAccent : wifiMaster.colMuted
                    }
                    Text {
                        text: wifiMaster.hotspotActive ? "Hotspot (Active)" : "Personal Hotspot"
                        font.family: "Noto Sans"
                        font.weight: wifiMaster.activeTab === "hotspot" ? Font.DemiBold : Font.Medium
                        font.pixelSize: 12
                        color: wifiMaster.activeTab === "hotspot" ? wifiMaster.colText : wifiMaster.colSubtext
                        renderType: Text.NativeRendering
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiMaster.activeTab = "hotspot" }
            }
        }
    }

    // ========================================================
    // 3. WI-FI TAB VIEW
    // ========================================================
    ColumnLayout {
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: wifiMaster.activeTab === "wifi"
        spacing: 6

        // Subheader: Switch + Title + Network count + Rescan
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 8

                MaterialSwitch {
                    checked: wifiMaster.wifiEnabled
                    onToggled: {
                        var target = wifiMaster.wifiEnabled ? "off" : "on";
                        wifiMaster.wifiEnabled = !wifiMaster.wifiEnabled;
                        wifiToggler.command = ["sh", "-c", "nmcli radio wifi " + target];
                        wifiToggler.running = true;
                    }
                }

                Text {
                    text: "Available Networks"
                    font.family: "Readex Pro"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: wifiMaster.colText
                    renderType: Text.NativeRendering
                }

                // Count Pill
                Rectangle {
                    visible: wifiMaster.wifiEnabled && wifiModel.count > 0
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: countText.implicitWidth + 12
                    radius: 11
                    color: wifiMaster.colChipBg

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: wifiModel.count + (wifiModel.count === 1 ? " network" : " networks")
                        font.family: "Rubik"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: wifiMaster.colSubtext
                        renderType: Text.NativeRendering
                    }
                }

                Item { Layout.fillWidth: true }

                // Refresh Scan Icon Button
                Rectangle {
                    visible: wifiMaster.wifiEnabled
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                    color: scanArea.containsMouse ? wifiMaster.colCardHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }

                    MaterialSymbol {
                        id: scanIcon
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 17
                        color: wifiMaster.isScanning ? wifiMaster.colAccent : wifiMaster.colSubtext

                        RotationAnimation on rotation {
                            running: wifiMaster.isScanning
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 900
                        }
                    }

                    MouseArea {
                        id: scanArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (!wifiMaster.isScanning) wifiMaster.triggerScan()
                    }
                }
            }

            // Scanning Progress Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                radius: 1.5
                color: "transparent"
                visible: wifiMaster.isScanning
                clip: true

                Rectangle {
                    id: scanBeam
                    width: parent.width * 0.35
                    height: parent.height
                    radius: 1.5
                    color: wifiMaster.colAccent

                    SequentialAnimation on x {
                        running: wifiMaster.isScanning
                        loops: Animation.Infinite
                        NumberAnimation { from: -scanBeam.width; to: wifiMaster.width; duration: 1100; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }

        // Wi-Fi Networks ListView
        ListView {
            id: wifiListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: wifiMaster.model
            boundsBehavior: Flickable.DragAndOvershootBounds
            maximumFlickVelocity: 2500
            flickDeceleration: 1500

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 3
                contentItem: Rectangle {
                    radius: 1.5
                    color: wifiMaster.colChipBg
                }
            }

            WheelHandler {
                target: wifiListView
                onWheel: (event) => {
                    if (event.angleDelta.y !== 0) {
                        var step = event.angleDelta.y > 0 ? -90 : 90;
                        wifiListView.contentY = Math.max(
                            0,
                            Math.min(wifiListView.contentHeight - wifiListView.height, wifiListView.contentY + step)
                        );
                        event.accepted = true;
                    }
                }
            }

            // Wi-Fi Disabled State
            Item {
                anchors.centerIn: parent
                width: parent.width
                visible: !wifiMaster.wifiEnabled
                height: 100

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "wifi_off"
                        iconSize: 30
                        color: wifiMaster.colMuted
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Wi-Fi is turned off"
                        font.family: "Noto Sans"
                        font.weight: Font.Medium
                        font.pixelSize: 13
                        color: wifiMaster.colSubtext
                        renderType: Text.NativeRendering
                    }
                }
            }

            // Network Card Delegate — Material 3 Expressive
            delegate: Rectangle {
                id: wifiCard
                width: ListView.view.width
                implicitHeight: networkCol.implicitHeight + 22
                radius: inUse ? 24 : 20
                color: inUse ? wifiMaster.colCardActive
                       : (rowPressArea.containsMouse ? wifiMaster.colCardHover : wifiMaster.colCard)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                property bool isCurrentlyConnecting: (wifiMaster.connectingSsid === ssid)

                ColumnLayout {
                    id: networkCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 13
                    spacing: 10

                    RowLayout {
                        id: networkRow
                        Layout.fillWidth: true
                        spacing: 12

                        // Signal badge
                        Rectangle {
                            width: 38; height: 38; radius: 14
                            color: inUse ? Qt.alpha(wifiMaster.colAccent, 0.25) : wifiMaster.colChipBg
                            Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 19
                                fill: inUse ? 1 : 0
                                text: inUse ? "wifi" : (signal > 75 ? "signal_wifi_4_bar" : signal > 50 ? "network_wifi_3_bar" : signal > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar")
                                color: inUse ? wifiMaster.colAccent : (signal > 50 ? wifiMaster.colText : wifiMaster.colSubtext)
                            }
                        }

                        // SSID + chips — capped so it can never crush the action controls
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 60
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: ssid
                                elide: Text.ElideRight
                                font.family: "Noto Sans"
                                font.pixelSize: 14
                                font.weight: inUse ? Font.Bold : Font.Medium
                                color: wifiMaster.colText
                                renderType: Text.NativeRendering
                            }

                            RowLayout {
                                spacing: 5

                                Rectangle {
                                    visible: typeof band !== "undefined" && band !== ""
                                    Layout.preferredHeight: 19
                                    Layout.preferredWidth: bandLabel.implicitWidth + 10
                                    radius: 6
                                    color: inUse ? Qt.alpha(wifiMaster.colAccent, 0.25) : wifiMaster.colChipBg

                                    Text {
                                        id: bandLabel
                                        anchors.centerIn: parent
                                        text: typeof band !== "undefined" ? band : ""
                                        font.family: "Rubik"
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        color: inUse ? wifiMaster.colAccent : wifiMaster.colMuted
                                        renderType: Text.NativeRendering
                                    }
                                }

                                Rectangle {
                                    visible: typeof rate !== "undefined" && rate !== ""
                                    Layout.preferredHeight: 19
                                    Layout.preferredWidth: rateLabel.implicitWidth + 10
                                    radius: 6
                                    color: wifiMaster.colChipBg

                                    Text {
                                        id: rateLabel
                                        anchors.centerIn: parent
                                        text: typeof rate !== "undefined" ? rate : ""
                                        font.family: "Rubik"
                                        font.pixelSize: 10
                                        font.weight: Font.Normal
                                        color: wifiMaster.colSubtext
                                        renderType: Text.NativeRendering
                                    }
                                }

                                Rectangle {
                                    visible: security !== "" && security !== "--"
                                    Layout.preferredHeight: 19
                                    Layout.preferredWidth: secLabel.implicitWidth + 10
                                    radius: 6
                                    color: wifiMaster.colChipBg

                                    Text {
                                        id: secLabel
                                        anchors.centerIn: parent
                                        text: security
                                        font.family: "Noto Sans"
                                        font.pixelSize: 10
                                        font.weight: Font.Normal
                                        color: wifiMaster.colMuted
                                        renderType: Text.NativeRendering
                                    }
                                }

                                // Text {
                                //     visible: inUse || isSaved
                                //     text: inUse ? "• Connected" : "• Saved"
                                //     font.family: "Noto Sans"
                                //     font.pixelSize: 10
                                //     color: inUse ? wifiMaster.colGreen : wifiMaster.colMuted
                                //     renderType: Text.NativeRendering
                                // }
                            }
                        }

                        // Signal % pill — hidden on the connected row to make room
                        // for the Disconnect button (previously always visible,
                        // which is what was squeezing Disconnect out of view).
                        Rectangle {
                            visible: !inUse
                            Layout.preferredHeight: 26
                            Layout.preferredWidth: sigRow.implicitWidth + 14
                            radius: 13
                            color: wifiMaster.colChipBg

                            RowLayout {
                                id: sigRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: signal + "%"
                                    font.family: "Rubik"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: wifiMaster.colSubtext
                                    renderType: Text.NativeRendering
                                }

                                MaterialSymbol {
                                    visible: security !== "" && security !== "--"
                                    text: "lock"
                                    iconSize: 12
                                    color: wifiMaster.colMuted
                                }
                            }
                        }

                        // Connecting status label
                        Text {
                            visible: isCurrentlyConnecting
                            text: "Connecting…"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: wifiMaster.colAccent
                            renderType: Text.NativeRendering
                        }

                        // Disconnect button — now guaranteed visible: fixed
                        // preferredWidth (not squeezable), never competes with
                        // the signal pill since that pill is hidden when inUse,
                        // and Layout.fillWidth on the SSID column has a
                        // minimumWidth cap so it can't eat this button's space.
                        Rectangle {
                            id: disconnectBtn
                            visible: inUse
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: disconnectRow.implicitWidth + 18
                            Layout.minimumWidth: disconnectRow.implicitWidth + 18
                            radius: 15
                            color: disconnectArea.containsMouse ? Qt.alpha(wifiMaster.colRed, 0.30) : Qt.alpha(wifiMaster.colRed, 0.20)
                            Behavior on color { ColorAnimation { duration: 140 } }

                            RowLayout {
                                id: disconnectRow
                                anchors.centerIn: parent
                                spacing: 5

                                MaterialSymbol {
                                    iconSize: 13
                                    text: "close"
                                    color: wifiMaster.colRed
                                }
                                Text {
                                    text: "Disconnect"
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: wifiMaster.colRed
                                    renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                id: disconnectArea
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: {
                                    wifiDisconnecter.command = ["sh", "-c", "nmcli connection down id '" + ssid + "' || nmcli dev disconnect wlan0"];
                                    wifiDisconnecter.running = true;
                                }
                            }
                        }

                        // Expand/collapse chevron
                        MaterialSymbol {
                            visible: !inUse && !isCurrentlyConnecting
                            text: "expand_more"
                            iconSize: 19
                            color: wifiMaster.colMuted
                            rotation: isExpanded ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                    }

                    // Drawer Actions (Connect, Forget, Auto-connect)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: (!inUse && isExpanded && !showPassword) ? implicitHeight : 0
                        visible: Layout.preferredHeight > 0
                        clip: true
                        spacing: 8
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        // Connect Button
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 14
                            color: isCurrentlyConnecting ? "transparent" : (connectArea.containsMouse ? Qt.lighter(wifiMaster.colAccent, 1.1) : wifiMaster.colAccent)
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Text { 
                                anchors.centerIn: parent
                                text: isCurrentlyConnecting ? "Connecting…" : "Connect"
                                color: isCurrentlyConnecting ? wifiMaster.colSubtext : wifiMaster.colSurface
                                font.family: "Noto Sans"
                                font.bold: true
                                font.pixelSize: 12
                                renderType: Text.NativeRendering
                            }
                            MouseArea {
                                id: connectArea
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !isCurrentlyConnecting; hoverEnabled: true
                                onClicked: {
                                    var isOpen = (security === "" || security === "--");
                                    if (isSaved || isOpen) {
                                        wifiMaster.initiateConnection(ssid, "", index);
                                    } else {
                                        wifiModel.setProperty(index, "showPassword", true);
                                        Qt.callLater(() => passField.forceActiveFocus());
                                    }
                                }
                            }
                        }

                        // Forget Button (if saved)
                        Rectangle {
                            visible: isSaved
                            Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 14
                            color: forgetArea.containsMouse ? Qt.alpha(wifiMaster.colRed, 0.25) : wifiMaster.colChipBg
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Text { 
                                anchors.centerIn: parent
                                text: "Forget"
                                color: forgetArea.containsMouse ? wifiMaster.colRed : wifiMaster.colSubtext
                                font.family: "Noto Sans"
                                font.weight: Font.Medium
                                font.pixelSize: 12
                                renderType: Text.NativeRendering
                            }
                            MouseArea {
                                id: forgetArea
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: {
                                    wifiForgetRunner.command = ["sh", "-c", "nmcli connection delete id '" + ssid + "' || true"];
                                    wifiForgetRunner.running = true;
                                    wifiModel.setProperty(index, "isSaved", false);
                                    wifiModel.setProperty(index, "isExpanded", false);
                                }
                            }
                        }

                        // Auto-connect Button
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 14
                            color: trustArea.containsMouse ? wifiMaster.colCardHover : wifiMaster.colChipBg
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Text { 
                                anchors.centerIn: parent
                                text: "Auto-connect"
                                color: wifiMaster.colSubtext
                                font.family: "Noto Sans"
                                font.weight: Font.Medium
                                font.pixelSize: 12
                                renderType: Text.NativeRendering
                            }
                            MouseArea {
                                id: trustArea
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: {
                                    wifiTrustRunner.command = ["sh", "-c", "nmcli connection modify id '" + ssid + "' connection.autoconnect yes || true"];
                                    wifiTrustRunner.running = true;
                                    wifiModel.setProperty(index, "isExpanded", false);
                                }
                            }
                        }
                    }

                    // Password input field
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: (!inUse && isExpanded && showPassword) ? implicitHeight : 0
                        visible: Layout.preferredHeight > 0
                        clip: true
                        spacing: 6
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            TextField {
                                id: passField
                                Layout.fillWidth: true; Layout.preferredHeight: 38
                                placeholderText: "Enter Wi-Fi password…"
                                placeholderTextColor: wifiMaster.colMuted
                                echoMode: TextInput.Password
                                color: wifiMaster.colText
                                font.family: "Noto Sans"
                                font.pixelSize: 12
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                enabled: !isCurrentlyConnecting
                                background: Rectangle {
                                    color: wifiMaster.colChipBg
                                    radius: 12
                                }
                                Keys.onReturnPressed: joinBtn.submit()
                                Keys.onEnterPressed: joinBtn.submit()
                            }

                            Rectangle {
                                id: joinBtn
                                Layout.preferredWidth: isCurrentlyConnecting ? 84 : 58
                                Layout.preferredHeight: 38
                                radius: 12
                                color: isCurrentlyConnecting ? wifiMaster.colCardHover : (joinArea.containsMouse ? Qt.lighter(wifiMaster.colAccent, 1.1) : wifiMaster.colAccent)
                                Behavior on Layout.preferredWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 140 } }
                                function submit() { if (!isCurrentlyConnecting) wifiMaster.initiateConnection(ssid, passField.text, index); }
                                
                                Text { 
                                    anchors.centerIn: parent
                                    text: isCurrentlyConnecting ? "Joining…" : "Join"
                                    color: isCurrentlyConnecting ? wifiMaster.colSubtext : wifiMaster.colSurface
                                    font.family: "Noto Sans"
                                    font.bold: true
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }
                                MouseArea { id: joinArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !isCurrentlyConnecting; hoverEnabled: true; onClicked: joinBtn.submit() }
                            }

                            Rectangle {
                                Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 12
                                color: cancelArea.containsMouse ? wifiMaster.colCardHover : "transparent"
                                enabled: !isCurrentlyConnecting
                                MaterialSymbol { 
                                    anchors.centerIn: parent
                                    text: "close"
                                    color: wifiMaster.colMuted
                                    iconSize: 16
                                }
                                MouseArea {
                                    id: cancelArea
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wifiModel.setProperty(index, "showPassword", false);
                                        wifiModel.setProperty(index, "isExpanded", false);
                                        wifiModel.setProperty(index, "hasError", false);
                                        wifiModel.setProperty(index, "errorMsg", "");
                                    }
                                }
                            }
                        }

                        Text {
                            visible: hasError
                            text: "⚠ " + errorMsg
                            color: wifiMaster.colRed
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // Row press/expand handling
                MouseArea {
                    id: rowPressArea
                    anchors.fill: parent
                    enabled: !inUse && !isCurrentlyConnecting && !showPassword
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    z: -1
                    onClicked: {
                        var next = !isExpanded;
                        for (var k = 0; k < wifiModel.count; k++) {
                            if (k !== index) {
                                wifiModel.setProperty(k, "isExpanded", false);
                                wifiModel.setProperty(k, "showPassword", false);
                            }
                        }
                        wifiModel.setProperty(index, "isExpanded", next);
                        wifiModel.setProperty(index, "showPassword", false);
                        wifiModel.setProperty(index, "hasError", false);
                    }
                }
            }
        }
    }

    // ========================================================
    // 4. HOTSPOT TAB VIEW — Material 3 Expressive
    // ========================================================
    ColumnLayout {
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: wifiMaster.activeTab === "hotspot"
        spacing: 12

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 26
            color: wifiMaster.colCard

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Rectangle {
                        width: 42; height: 42; radius: 16
                        color: wifiMaster.hotspotActive ? Qt.alpha(wifiMaster.colAccent, 0.25) : wifiMaster.colChipBg
                        Behavior on color { ColorAnimation { duration: 200 } }
                        MaterialSymbol { 
                            anchors.centerIn: parent
                            text: "wifi_tethering"
                            iconSize: 22
                            fill: wifiMaster.hotspotActive ? 1 : 0
                            color: wifiMaster.hotspotActive ? wifiMaster.colAccent : wifiMaster.colSubtext
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { 
                            text: "Personal Hotspot"
                            font.family: "Noto Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 14
                            color: wifiMaster.colText
                            renderType: Text.NativeRendering
                        }
                        Text { 
                            text: wifiMaster.hotspotActive ? "Broadcasting live" : "Inactive"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            color: wifiMaster.hotspotActive ? wifiMaster.colAccent : wifiMaster.colMuted
                            renderType: Text.NativeRendering
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { 
                        text: "Hotspot Name (SSID)"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: wifiMaster.colSubtext
                        renderType: Text.NativeRendering
                    }
                    TextField {
                        id: hotspotSsidField
                        Layout.fillWidth: true; Layout.preferredHeight: 38
                        text: wifiMaster.hotspotSsid
                        color: wifiMaster.colText
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        onTextChanged: wifiMaster.hotspotSsid = text
                        background: Rectangle { 
                            color: wifiMaster.colChipBg
                            radius: 12
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { 
                        text: "Password (min. 8 characters)"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: wifiMaster.colSubtext
                        renderType: Text.NativeRendering
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        TextField {
                            id: hotspotPassField
                            Layout.fillWidth: true; Layout.preferredHeight: 38
                            text: wifiMaster.hotspotPass
                            echoMode: wifiMaster.hotspotShowPassword ? TextInput.Normal : TextInput.Password
                            color: wifiMaster.colText
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            onTextChanged: wifiMaster.hotspotPass = text
                            background: Rectangle { 
                                color: wifiMaster.colChipBg
                                radius: 12
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 12
                            color: eyeArea.containsMouse ? wifiMaster.colCardHover : wifiMaster.colChipBg
                            MaterialSymbol { 
                                anchors.centerIn: parent
                                text: wifiMaster.hotspotShowPassword ? "visibility" : "visibility_off"
                                iconSize: 18
                                color: wifiMaster.colSubtext
                            }
                            MouseArea { id: eyeArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: wifiMaster.hotspotShowPassword = !wifiMaster.hotspotShowPassword }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 16
                    color: wifiMaster.hotspotActive ? wifiMaster.colRed : (startArea.containsMouse ? Qt.lighter(wifiMaster.colAccent, 1.1) : wifiMaster.colAccent)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        MaterialSymbol { 
                            text: wifiMaster.hotspotActive ? "power_settings_new" : "wifi_tethering"
                            iconSize: 17
                            color: wifiMaster.hotspotActive ? "#ffffff" : wifiMaster.colSurface
                        }
                        Text { 
                            text: wifiMaster.hotspotActive ? "Stop Hotspot" : "Start Hotspot"
                            font.family: "Noto Sans"
                            font.bold: true
                            font.pixelSize: 12
                            color: wifiMaster.hotspotActive ? "#ffffff" : wifiMaster.colSurface
                            renderType: Text.NativeRendering
                        }
                    }
                    MouseArea { id: startArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: wifiMaster.toggleHotspot(!wifiMaster.hotspotActive) }
                }
            }
        }
    }

    // ========================================================
    // 5. MATERIAL SWITCH COMPONENT — Expressive Motion
    // ========================================================
    component MaterialSwitch: Item {
        id: switchRoot
        implicitWidth: 40
        implicitHeight: 24

        property bool checked: false
        signal toggled()

        Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: switchRoot.checked ? wifiMaster.colAccent : wifiMaster.colChipBg
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Rectangle {
                id: thumb
                height: switchRoot.checked ? parent.height - 4 : parent.height - 8
                width: height
                radius: height / 2
                color: switchRoot.checked ? wifiMaster.colSurface : wifiMaster.colText
                anchors.verticalCenter: parent.verticalCenter
                x: switchRoot.checked ? parent.width - width - 2 : 4

                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1, 1, 1] } }
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: switchMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: switchRoot.toggled()
        }
    }
}
