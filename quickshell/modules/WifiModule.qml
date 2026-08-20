import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
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

    property string hotspotSsid: "SubhamLaptop"
    property string hotspotPass: "000000001"
    property bool hotspotShowPassword: false

    // Tokyo Night fallbacks (used only when Theme.colors.* is missing) —
    // these match the literal fallback colors used in BluetoothModule.qml
    // so the two panels look consistent even before Theme.colors resolves.
    readonly property color cBase: "#16161e"
    readonly property color cMantle: "#16161e"
    readonly property color cSurface0: "#1f2335"
    readonly property color cSurface1: "#24283b"
    readonly property color cOverlay0: "#565f89"
    readonly property color cText: "#ffffff"
    readonly property color cSubtext0: "#565f89"
    readonly property color cBlue: "#7aa2f7"
    readonly property color cRed: "#f44336"
    readonly property color cGreen: "#9ece6a"

    readonly property alias model: wifiModel

    function isAnyWifiExpanded() {
        if (connectingSsid !== "") return true;
        for (var i = 0; i < wifiModel.count; i++) {
            if (wifiModel.get(i).isExpanded) return true;
        }
        return false;
    }

    ListModel { id: wifiModel }

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
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan no 2>/dev/null | awk -F':' '{ if ($2 != \"\" && $2 != \"--\") { in_use=($1==\"*\")?1:0; print in_use \"|||\" $2 \"|||\" $3 \"|||\" $4 } }'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                // Parse fresh scan results into a keyed map first.
                var lines = this.text.trim().split("\n");
                var fresh = {};
                var order = [];
                var foundActive = "";

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    var parts = line.split("|||");
                    if (parts.length >= 4) {
                        var isConn = (parts[0] === "1");
                        var ssidName = parts[1].replace(/\\:/g, ":").trim();
                        var sig = parseInt(parts[2]) || 0;
                        var sec = parts[3].trim();

                        if (ssidName === "" || ssidName === "--") continue;
                        if (isConn) foundActive = ssidName;

                        if (!fresh[ssidName] || isConn || sig > fresh[ssidName].signal) {
                            if (!fresh[ssidName]) order.push(ssidName);
                            fresh[ssidName] = {
                                "inUse": isConn,
                                "ssid": ssidName,
                                "signal": sig,
                                "security": sec,
                                "isSaved": !!wifiMaster.savedConnections[ssidName]
                            };
                        }
                    }
                }

                // In-place reconcile against the existing model instead of
                // clear()+append(), so delegates that already exist are not
                // destroyed/recreated (that's what caused the every-scan
                // flicker/jump animation on every row, not just new ones).

                // 1) Update existing rows in place; remove rows no longer seen.
                for (var idx = wifiModel.count - 1; idx >= 0; idx--) {
                    var row = wifiModel.get(idx);
                    var upd = fresh[row.ssid];
                    if (!upd) {
                        // Network fell out of range - only drop it if it's not
                        // mid-interaction (expanded / showing an error).
                        if (!row.isExpanded && !row.hasError) {
                            wifiModel.remove(idx);
                        }
                        continue;
                    }
                    if (row.inUse !== upd.inUse) wifiModel.setProperty(idx, "inUse", upd.inUse);
                    if (row.signal !== upd.signal) wifiModel.setProperty(idx, "signal", upd.signal);
                    if (row.security !== upd.security) wifiModel.setProperty(idx, "security", upd.security);
                    if (row.isSaved !== upd.isSaved) wifiModel.setProperty(idx, "isSaved", upd.isSaved);
                    delete fresh[upd.ssid]; // mark handled
                }

                // 2) Append genuinely new networks only (these are the only
                // rows that should ever play the "arrival" animation).
                for (var o = 0; o < order.length; o++) {
                    var name = order[o];
                    var f = fresh[name];
                    if (!f) continue; // already reconciled above
                    wifiModel.append({
                        "inUse": f.inUse,
                        "ssid": f.ssid,
                        "signal": f.signal,
                        "security": f.security,
                        "isSaved": f.isSaved,
                        "isExpanded": false,
                        "showPassword": false,
                        "hasError": false,
                        "errorMsg": ""
                    });
                }

                wifiMaster.activeWifiSsid = foundActive;
                wifiMaster.isScanning = false;
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
                        wifiModel.setProperty(i, "errorMsg", "Incorrect password or network timed out.");
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
        }
    }

    function initiateConnection(ssid, password, idx) {
        wifiMaster.connectingSsid = ssid;
        wifiModel.setProperty(idx, "hasError", false);
        wifiModel.setProperty(idx, "errorMsg", "");
        wifiConnector.targetSsid = ssid;

        var safeSsid = ssid.replace(/'/g, "'\\''");
        var cmd = (password && password.length > 0)
            ? "nmcli dev wifi connect '" + safeSsid + "' password '" + password.replace(/'/g, "'\\''") + "'"
            : "nmcli connection up id '" + safeSsid + "' 2>/dev/null || nmcli dev wifi connect '" + safeSsid + "'";

        wifiConnector.command = ["sh", "-c", cmd];
        wifiConnector.running = true;
    }

    Process { id: wifiDisconnecter; running: false; onExited: wifiSavedChecker.running = true }
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
            var safeSsid = hotspotSsid.replace(/'/g, "'\\''");
            var safePass = hotspotPass.replace(/'/g, "'\\''");
            var cmd = "nmcli radio wifi on && sleep 0.5 && nmcli device wifi hotspot ssid '" + safeSsid + "' password '" + safePass + "'";
            hotspotRunner.command = ["sh", "-c", cmd];
            hotspotRunner.running = true;
        } else {
            hotspotRunner.command = ["sh", "-c", "nmcli connection down Hotspot || nmcli connection down id '" + hotspotSsid.replace(/'/g, "'\\''") + "' || true"];
            hotspotRunner.running = true;
        }
    }

    function refreshStatus() {
        wifiStatusChecker.running = true;
        wifiSavedChecker.running = true;
        hotspotStatusChecker.running = true;
    }

    Timer {
        interval: 4000; running: root.activeMode === "wifi"; repeat: true
        onTriggered: {
            if (!wifiMaster.isScanning && !wifiMaster.isAnyWifiExpanded()) wifiSavedChecker.running = true;
            hotspotStatusChecker.running = true;
        }
    }

    // ===== Current Connection Status =====
    Rectangle {
        Layout.fillWidth: true; height: 44; radius: 10
        color: Theme.colors.hover_bg ?? wifiMaster.cSurface1
        border.width: 1; border.color: Theme.colors.border ?? wifiMaster.cBase
        
        RowLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 10
            
            Rectangle {
                width: 28; height: 28; radius: 14
                color: Theme.colors.accent ?? wifiMaster.cBlue
                opacity: 0.15
                Text {
                    anchors.centerIn: parent
                    text: (typeof dashMod !== "undefined" && dashMod.activeNetType === "eth") ? "󰈀" : 
                          ((typeof dashMod !== "undefined" && dashMod.activeNetSignal > 75) ? "󰤨" : 
                          ((typeof dashMod !== "undefined" && dashMod.activeNetSignal > 50) ? "󰤥" : 
                          ((typeof dashMod !== "undefined" && dashMod.activeNetSignal > 25) ? "󰤢" : 
                          ((typeof dashMod !== "undefined" && dashMod.activeNetType !== "") ? "󰤟" : "󰖩"))))
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                    color: Theme.colors.accent ?? wifiMaster.cBlue
                }
            }
            Text {
                Layout.fillWidth: true
                text: {
                    if (typeof dashMod === "undefined") return "Network status";
                    if (dashMod.activeNetName === "") return dashMod.activeNetType === "eth" ? "Ethernet disconnected" : "Wi-Fi disconnected";
                    return (dashMod.activeNetType === "eth" ? "Ethernet · " : "Wi-Fi · ") + dashMod.activeNetName;
                }
                font.pixelSize: 13; font.bold: true
                color: Theme.colors.text_primary ?? wifiMaster.cText
                elide: Text.ElideRight
            }
        }
    }

    // ===== Tab Switcher (Android segmented control) =====
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 20
        color: Theme.colors.hover_bg ?? wifiMaster.cSurface1

        RowLayout {
            anchors.fill: parent; anchors.margins: 3; spacing: 3

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 17
                color: wifiMaster.activeTab === "wifi" ? (Theme.colors.accent ?? wifiMaster.cBlue) : "transparent"
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
                RowLayout {
                    anchors.centerIn: parent; spacing: 6
                    Text { text: "󰖩"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: wifiMaster.activeTab === "wifi" ? (Theme.colors.bg ?? wifiMaster.cMantle) : (Theme.colors.text_secondary ?? wifiMaster.cSubtext0) }
                    Text { text: "Wi-Fi"; font.weight: Font.Medium; font.pixelSize: 12; color: wifiMaster.activeTab === "wifi" ? (Theme.colors.bg ?? wifiMaster.cMantle) : (Theme.colors.text_primary ?? wifiMaster.cText) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiMaster.activeTab = "wifi" }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 17
                color: wifiMaster.activeTab === "hotspot" ? (Theme.colors.accent ?? wifiMaster.cBlue) : "transparent"
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
                RowLayout {
                    anchors.centerIn: parent; spacing: 6
                    Text { text: "󰖪"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: wifiMaster.activeTab === "hotspot" ? (Theme.colors.bg ?? wifiMaster.cMantle) : (Theme.colors.text_secondary ?? wifiMaster.cSubtext0) }
                    Text { text: wifiMaster.hotspotActive ? "Hotspot · On" : "Hotspot"; font.weight: Font.Medium; font.pixelSize: 12; color: wifiMaster.activeTab === "hotspot" ? (Theme.colors.bg ?? wifiMaster.cMantle) : (Theme.colors.text_primary ?? wifiMaster.cText) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiMaster.activeTab = "hotspot" }
            }
        }
    }

    // ===== Wi-Fi Tab View =====
    ColumnLayout {
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: wifiMaster.activeTab === "wifi"
        spacing: 8

        // Single compact header row: toggle + scan button. Replaces the old
        // stacked "Internet" title / separate toggle card / "N networks
        // available" caption — that ate ~90px of vertical space that's now
        // given back to the list so SSID names are actually visible.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            Layout.topMargin: 6
            spacing: 8

            CaelestiaSwitch {
                checked: wifiMaster.wifiEnabled
                onToggled: {
                    var target = wifiMaster.wifiEnabled ? "off" : "on";
                    wifiMaster.wifiEnabled = !wifiMaster.wifiEnabled;
                    wifiToggler.command = ["sh", "-c", "nmcli radio wifi " + target];
                    wifiToggler.running = true;
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Wi-Fi"
                font.pixelSize: 14; font.bold: true
                color: Theme.colors.text_primary ?? wifiMaster.cText
            }

            Rectangle {
                visible: wifiMaster.wifiEnabled
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                color: "transparent"

                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    color: Theme.colors.text_primary ?? wifiMaster.cText
                    opacity: scanArea.containsMouse ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                    color: Theme.colors.text_primary ?? wifiMaster.cText
                    opacity: wifiMaster.isScanning ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Canvas {
                    id: scanSpinner
                    anchors.centerIn: parent
                    width: 16; height: 16
                    visible: wifiMaster.isScanning

                    property real head: 0
                    property real tail: 0
                    Connections { target: Theme; function onColorsChanged() { scanSpinner.requestPaint() } }
                    onHeadChanged: requestPaint()
                    onTailChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.beginPath();
                        var startAngle = (tail - 90) * Math.PI / 180;
                        var endAngle = (head - 90) * Math.PI / 180;
                        if (endAngle - startAngle < 0.05) endAngle = startAngle + 0.05;
                        ctx.arc(width/2, height/2, width/2 - 2, startAngle, endAngle, false);
                        ctx.strokeStyle = Theme.colors.accent ?? wifiMaster.cBlue;
                        ctx.lineWidth = 1.5;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }

                    RotationAnimation on rotation { loops: Animation.Infinite; from: 0; to: 360; duration: 1600; running: wifiMaster.isScanning }
                    SequentialAnimation {
                        running: wifiMaster.isScanning
                        loops: Animation.Infinite
                        ParallelAnimation {
                            NumberAnimation { target: scanSpinner; property: "head"; from: 0; to: 280; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { target: scanSpinner; property: "tail"; from: 0; to: 0; duration: 700; easing.type: Easing.InOutSine }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: scanSpinner; property: "head"; from: 280; to: 360; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { target: scanSpinner; property: "tail"; from: 0; to: 360; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }
                }

                MouseArea {
                    id: scanArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (!wifiMaster.isScanning) wifiMaster.triggerScan()
                }
            }
        }

        // ===== Wi-Fi Networks ListView =====
		ListView {
			id: wifiListView
			Layout.fillWidth: true
			Layout.fillHeight: true
			clip: true
			spacing: 6
			model: wifiMaster.model
			boundsBehavior: Flickable.DragAndOvershootBounds
			maximumFlickVelocity: 2500
			flickDeceleration: 1500

			// ScrollBar indicator
			ScrollBar.vertical: ScrollBar {
				policy: ScrollBar.AsNeeded
				width: 4
				contentItem: Rectangle {
					radius: 2
					color: Theme.colors.accent ?? "#7aa2f7"
					opacity: 0.5
				}
			}

			// Direct Mouse Wheel Scroll Handler
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

            Item {
                anchors.centerIn: parent
                width: parent.width
                visible: !wifiMaster.wifiEnabled
                height: 120
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰖪"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 28
                        color: Theme.colors.text_secondary ?? wifiMaster.cOverlay0
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Wi-Fi is off"
                        color: Theme.colors.text_secondary ?? wifiMaster.cSubtext0
                        font.pixelSize: 13
                    }
                }
            }

            // Only genuinely new delegates animate in (add transition).
            // Existing delegates whose model data changes in place do NOT
            // get recreated, so they no longer replay this animation on
            // every rescan tick.
            add: Transition {
                NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { properties: "scale"; from: 0.85; to: 1; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
            addDisplaced: Transition {
                NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
            }
            displaced: Transition {
                NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
            }
            remove: Transition {
                NumberAnimation { properties: "opacity"; to: 0; duration: 150 }
            }
            removeDisplaced: Transition {
                NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
            }

            delegate: Rectangle {
                id: wifiCard
                width: ListView.view.width
                implicitHeight: networkCol.implicitHeight + 20
                radius: 10
                color: inUse ? Qt.rgba(
                        (Theme.colors.accent ?? wifiMaster.cBlue).r,
                        (Theme.colors.accent ?? wifiMaster.cBlue).g,
                        (Theme.colors.accent ?? wifiMaster.cBlue).b, 0.12)
                       : (rowPressArea.containsMouse ? (Theme.colors.hover_bg ?? wifiMaster.cSurface1) : "transparent")
                border.width: 1
                border.color: inUse ? (Theme.colors.accent ?? wifiMaster.cBlue) : (Theme.colors.border ?? wifiMaster.cBase)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                property bool isCurrentlyConnecting: (wifiMaster.connectingSsid === ssid)

                ColumnLayout {
                    id: networkCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        id: networkRow
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: inUse ? "󰖩" : (signal > 75 ? "󰤨" : (signal > 50 ? "󰤥" : (signal > 25 ? "󰤢" : "󰤟")))
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17
                            color: inUse ? (Theme.colors.accent ?? wifiMaster.cBlue) : (Theme.colors.text_secondary ?? wifiMaster.cSubtext0)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: ssid
                                elide: Text.ElideRight
                                font.pixelSize: 15
                                font.weight: inUse ? Font.DemiBold : Font.Medium
                                color: inUse ? (Theme.colors.accent ?? wifiMaster.cBlue) : (Theme.colors.text_primary ?? wifiMaster.cText)
                            }
                            Text {
                                visible: inUse || (security !== "" && security !== "--")
                                text: inUse ? "Connected" : "Secured"
                                font.pixelSize: 11
                                color: Theme.colors.text_secondary ?? wifiMaster.cSubtext0
                            }
                        }

                        Text {
                            visible: security !== "" && security !== "--" && !inUse
                            text: "󰌾"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                            color: Theme.colors.text_secondary ?? wifiMaster.cSubtext0
                        }

                        // Trailing action: chevron / connecting spinner
                        Text {
                            visible: !inUse && !isCurrentlyConnecting
                            text: isExpanded ? "󰅃" : "󰅀"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                            color: Theme.colors.text_secondary ?? wifiMaster.cOverlay0
                            Behavior on rotation { NumberAnimation { duration: 180 } }
                        }
                        Text {
                            visible: isCurrentlyConnecting
                            text: "Connecting…"
                            font.pixelSize: 11
                            color: Theme.colors.accent ?? wifiMaster.cBlue
                        }
                        Rectangle {
                            visible: inUse
                            Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                            color: "transparent"
                            Rectangle {
                                anchors.fill: parent; radius: 13
                                color: Theme.colors.text_primary ?? wifiMaster.cText
                                opacity: disconnectArea.containsMouse ? 0.1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰌹"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                color: Theme.colors.accent ?? wifiMaster.cBlue
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
                    }

                    // Drawer Actions (Android bottom-sheet-like row of chips)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: (!inUse && isExpanded && !showPassword) ? implicitHeight : 0
                        visible: Layout.preferredHeight > 0
                        clip: true
                        spacing: 8
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8
                            color: isCurrentlyConnecting ? "transparent" : (Theme.colors.accent ?? wifiMaster.cBlue)

                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: Theme.colors.text_primary ?? wifiMaster.cText
                                opacity: connectArea.containsMouse ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Text { anchors.centerIn: parent; text: isCurrentlyConnecting ? "Connecting…" : "Connect"; color: isCurrentlyConnecting ? (Theme.colors.text_secondary ?? wifiMaster.cSubtext0) : (Theme.colors.bg ?? wifiMaster.cMantle); font.bold: true; font.pixelSize: 11 }
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

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8
                            color: Theme.colors.hover_bg ?? wifiMaster.cSurface1
                            border.width: 1
                            border.color: Theme.colors.border ?? wifiMaster.cBase

                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: Theme.colors.text_secondary ?? wifiMaster.cSubtext0
                                opacity: forgetArea.containsMouse ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Text { anchors.centerIn: parent; text: "Forget"; color: Theme.colors.text_primary ?? wifiMaster.cText; font.bold: true; font.pixelSize: 11 }
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

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8
                            color: Theme.colors.hover_bg ?? wifiMaster.cSurface1
                            border.width: 1
                            border.color: Theme.colors.border ?? wifiMaster.cBase

                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: Theme.colors.text_secondary ?? wifiMaster.cSubtext0
                                opacity: trustArea.containsMouse ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Text { anchors.centerIn: parent; text: "Trust"; color: Theme.colors.text_primary ?? wifiMaster.cText; font.bold: true; font.pixelSize: 11 }
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

                    // Password field (Android-style inline expand)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: (!inUse && isExpanded && showPassword) ? implicitHeight : 0
                        visible: Layout.preferredHeight > 0
                        clip: true
                        spacing: 4
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            TextField {
                                id: passField
                                Layout.fillWidth: true; Layout.preferredHeight: 34
                                placeholderText: "Enter password…"
                                placeholderTextColor: Theme.colors.text_secondary ?? wifiMaster.cOverlay0
                                echoMode: TextInput.Password; color: Theme.colors.text_primary ?? wifiMaster.cText
                                font.pixelSize: 12; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                enabled: !isCurrentlyConnecting
                                background: Rectangle {
                                    color: Theme.colors.bg ?? wifiMaster.cMantle; radius: 8; border.width: 1
                                    border.color: hasError ? (Theme.colors.red ?? wifiMaster.cRed) : (passField.activeFocus ? (Theme.colors.accent ?? wifiMaster.cBlue) : (Theme.colors.border ?? wifiMaster.cBase))
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                }
                                Keys.onReturnPressed: joinBtn.submit()
                                Keys.onEnterPressed: joinBtn.submit()
                            }

                            Rectangle {
                                id: joinBtn
                                Layout.preferredWidth: isCurrentlyConnecting ? 78 : 50; Layout.preferredHeight: 34; radius: 8
                                color: isCurrentlyConnecting ? "transparent" : (Theme.colors.accent ?? wifiMaster.cBlue)
                                Behavior on Layout.preferredWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                function submit() { if (!isCurrentlyConnecting) wifiMaster.initiateConnection(ssid, passField.text, index); }
                                Text { anchors.centerIn: parent; text: isCurrentlyConnecting ? "Joining…" : "Join"; color: isCurrentlyConnecting ? (Theme.colors.text_primary ?? wifiMaster.cText) : (Theme.colors.bg ?? wifiMaster.cMantle); font.bold: true; font.pixelSize: 11 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !isCurrentlyConnecting; onClicked: joinBtn.submit() }
                            }

                            Rectangle {
                                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 8; color: "transparent"
                                enabled: !isCurrentlyConnecting
                                Text { anchors.centerIn: parent; text: "󰅖"; font.family: "JetBrainsMono Nerd Font"; color: Theme.colors.text_secondary ?? wifiMaster.cSubtext0; font.pixelSize: 13 }
                                MouseArea {
                                    anchors.fill: parent
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
                            color: Theme.colors.red ?? wifiMaster.cRed
                            font.pixelSize: 11; font.weight: Font.Medium
                            elide: Text.ElideRight; Layout.fillWidth: true
                            Layout.topMargin: 2
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

    // ===== Hotspot Tab View =====
    ColumnLayout {
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: wifiMaster.activeTab === "hotspot"
        spacing: 12

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 12
            color: Theme.colors.card_bg ?? wifiMaster.cSurface0
            border.width: wifiMaster.hotspotActive ? 1 : 0
            border.color: Theme.colors.accent ?? wifiMaster.cBlue
            Behavior on border.width { NumberAnimation { duration: 200 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 16
                anchors.bottomMargin: 20 // Increased bottom padding inside the card
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        color: wifiMaster.hotspotActive ? (Theme.colors.accent ?? wifiMaster.cBlue) : (Theme.colors.hover_bg ?? wifiMaster.cSurface1)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Text { anchors.centerIn: parent; text: "󰖪"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: wifiMaster.hotspotActive ? (Theme.colors.bg ?? wifiMaster.cMantle) : (Theme.colors.text_secondary ?? wifiMaster.cSubtext0) }
                    }
                    Column {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Access Point Hotspot"; font.weight: Font.DemiBold; font.pixelSize: 14; color: Theme.colors.text_primary ?? wifiMaster.cText }
                        Text { text: wifiMaster.hotspotActive ? "Broadcasting live" : "Inactive"; font.pixelSize: 11; color: wifiMaster.hotspotActive ? (Theme.colors.accent ?? wifiMaster.cBlue) : (Theme.colors.text_secondary ?? wifiMaster.cSubtext0) }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "Hotspot name (SSID)"; font.pixelSize: 11; font.weight: Font.Medium; color: Theme.colors.text_secondary ?? wifiMaster.cSubtext0 }
                    TextField {
                        id: hotspotSsidField
                        Layout.fillWidth: true; Layout.preferredHeight: 36
                        text: wifiMaster.hotspotSsid
                        color: Theme.colors.text_primary ?? wifiMaster.cText; font.pixelSize: 13; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                        onTextChanged: wifiMaster.hotspotSsid = text
                        background: Rectangle { color: Theme.colors.bg ?? wifiMaster.cMantle; radius: 8; border.width: 1; border.color: hotspotSsidField.activeFocus ? (Theme.colors.accent ?? wifiMaster.cBlue) : (Theme.colors.border ?? wifiMaster.cBase) }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "Password (min. 8 characters)"; font.pixelSize: 11; font.weight: Font.Medium; color: Theme.colors.text_secondary ?? wifiMaster.cSubtext0 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        TextField {
                            id: hotspotPassField
                            Layout.fillWidth: true; Layout.preferredHeight: 36
                            text: wifiMaster.hotspotPass
                            echoMode: wifiMaster.hotspotShowPassword ? TextInput.Normal : TextInput.Password
                            color: Theme.colors.text_primary ?? wifiMaster.cText; font.pixelSize: 13; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onTextChanged: wifiMaster.hotspotPass = text
                            background: Rectangle { color: Theme.colors.bg ?? wifiMaster.cMantle; radius: 8; border.width: 1; border.color: hotspotPassField.activeFocus ? (Theme.colors.accent ?? wifiMaster.cBlue) : (Theme.colors.border ?? wifiMaster.cBase) }
                        }
                        Rectangle {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 8; color: Theme.colors.hover_bg ?? wifiMaster.cSurface1
                            Text { anchors.centerIn: parent; text: wifiMaster.hotspotShowPassword ? "󰈈" : "󰈉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.colors.text_primary ?? wifiMaster.cText }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiMaster.hotspotShowPassword = !wifiMaster.hotspotShowPassword }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 10
                    color: wifiMaster.hotspotActive ? (Theme.colors.red ?? wifiMaster.cRed) : (Theme.colors.accent ?? wifiMaster.cBlue)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: wifiMaster.hotspotActive ? "󰐥" : "󰖪"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.colors.bg ?? wifiMaster.cMantle }
                        Text { text: wifiMaster.hotspotActive ? "Stop hotspot" : "Start hotspot"; font.bold: true; font.pixelSize: 13; color: Theme.colors.bg ?? wifiMaster.cMantle }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiMaster.toggleHotspot(!wifiMaster.hotspotActive) }
                }
            }
        }
    }


    component CaelestiaSwitch: Item {
        id: switchRoot
        implicitWidth: implicitHeight * 1.7
        implicitHeight: 22

        property bool checked: false
        signal toggled()

        Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: switchRoot.checked ? (Theme.colors.accent ?? wifiMaster.cBlue) : (Theme.colors.hover_bg ?? wifiMaster.cSurface1)
            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Rectangle {
                id: thumb
                height: parent.height - 4
                width: switchMouse.pressed ? height * 1.3 : height
                radius: height / 2
                color: switchRoot.checked ? (Theme.colors.bg ?? wifiMaster.cMantle) : (Theme.colors.text_primary ?? wifiMaster.cText)
                anchors.verticalCenter: parent.verticalCenter
                x: switchRoot.checked ? parent.width - width - 2 : 2

                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
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
