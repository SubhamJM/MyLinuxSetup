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
    property bool isScanning: false
    property var savedConnections: ({})
    property string connectingSsid: ""

    property string hotspotSsid: "SubhamLaptop"
    property string hotspotPass: "000000001"
    property bool hotspotShowPassword: false

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
                var stateMap = {};
                for (var k = 0; k < wifiModel.count; k++) {
                    var itm = wifiModel.get(k);
                    if (itm.isExpanded || itm.hasError) {
                        stateMap[itm.ssid] = {
                            "isExpanded": itm.isExpanded,
                            "showPassword": itm.showPassword,
                            "hasError": itm.hasError,
                            "errorMsg": itm.errorMsg
                        };
                    }
                }

                wifiModel.clear();
                var lines = this.text.trim().split("\n");
                var seen = {};
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

                        if (!seen[ssidName] || isConn || sig > seen[ssidName].signal) {
                            var prev = stateMap[ssidName];
                            seen[ssidName] = {
                                "inUse": isConn,
                                "ssid": ssidName,
                                "signal": sig,
                                "security": sec,
                                "isSaved": !!wifiMaster.savedConnections[ssidName],
                                "isExpanded": prev ? prev.isExpanded : false,
                                "showPassword": prev ? prev.showPassword : false,
                                "hasError": prev ? prev.hasError : false,
                                "errorMsg": prev ? prev.errorMsg : ""
                            };
                        }
                    }
                }

                for (var s in seen) wifiModel.append(seen[s]);
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

    // Tab Switcher
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.fillWidth: true; height: 32; radius: 8
            color: Theme.colors.card_bg ?? "#1f2335"
            border.width: 1; border.color: Theme.colors.border ?? "#16161e"

            RowLayout {
                anchors.fill: parent; anchors.margins: 3; spacing: 4

                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 6
                    color: wifiMaster.activeTab === "wifi" ? (Theme.colors.accent ?? "#7aa2f7") : "transparent"
                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "󰖩"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: wifiMaster.activeTab === "wifi" ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_secondary ?? "#565f89") }
                        Text { text: "Wi-Fi"; font.bold: true; font.pixelSize: 12; color: wifiMaster.activeTab === "wifi" ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white") }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiMaster.activeTab = "wifi" }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 6
                    color: wifiMaster.activeTab === "hotspot" ? (Theme.colors.accent ?? "#7aa2f7") : "transparent"
                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "󰖪"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: wifiMaster.activeTab === "hotspot" ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_secondary ?? "#565f89") }
                        Text { text: wifiMaster.hotspotActive ? "Hotspot (ON)" : "Hotspot"; font.bold: true; font.pixelSize: 12; color: wifiMaster.activeTab === "hotspot" ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white") }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiMaster.activeTab = "hotspot" }
                }
            }
        }
    }

    // Wi-Fi Tab View
    ColumnLayout {
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: wifiMaster.activeTab === "wifi"
        spacing: 8

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: "Available Networks"; font.pixelSize: 13; font.bold: true; color: Theme.colors.text_primary ?? "white" }
            Item { Layout.fillWidth: true }

            Rectangle {
                width: 64; height: 26; radius: 6
                color: wifiMaster.isScanning ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.card_bg ?? "#1f2335")
                border.width: 1; border.color: wifiMaster.isScanning ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")
                Text { anchors.centerIn: parent; text: wifiMaster.isScanning ? "Scanning..." : "Scan"; color: wifiMaster.isScanning ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white"); font.bold: true; font.pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!wifiMaster.isScanning) wifiMaster.triggerScan() }
            }

            Rectangle {
                width: 60; height: 26; radius: 13
                color: wifiMaster.wifiEnabled ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.hover_bg ?? "#24283b")
                border.width: 1; border.color: Theme.colors.border_hover ?? "#7aa2f7"

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 4
                    Text { text: wifiMaster.wifiEnabled ? "ON" : "OFF"; font.bold: true; font.pixelSize: 10; color: wifiMaster.wifiEnabled ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_secondary ?? "#565f89") }
                    Item { Layout.fillWidth: true }
                    Rectangle { width: 16; height: 16; radius: 8; color: wifiMaster.wifiEnabled ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_secondary ?? "#565f89") }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var target = wifiMaster.wifiEnabled ? "off" : "on";
                        wifiMaster.wifiEnabled = !wifiMaster.wifiEnabled;
                        wifiToggler.command = ["sh", "-c", "nmcli radio wifi " + target];
                        wifiToggler.running = true;
                    }
                }
            }
        }

        ListView {
            id: wifiListView
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
            model: wifiMaster.wifiEnabled ? wifiModel : []

            Item {
                anchors.fill: parent; visible: !wifiMaster.wifiEnabled
                Text { anchors.centerIn: parent; text: "Wi-Fi is disabled"; color: Theme.colors.text_secondary ?? "#565f89"; font.pixelSize: 13 }
            }

            delegate: Rectangle {
                id: wifiCard
                width: ListView.view.width
                height: inUse ? 50 : (isExpanded ? (showPassword ? (hasError ? 138 : 116) : 84) : 48)
                radius: 8; color: Theme.colors.card_bg ?? "#1f2335"
                border.width: 1
                border.color: inUse ? (Theme.colors.accent ?? "#7aa2f7") : (hasError ? "#f44336" : (isExpanded ? (Theme.colors.border_hover ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")))
                clip: true

                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
                property bool isCurrentlyConnecting: (wifiMaster.connectingSsid === ssid)

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 6

                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Text {
                            text: inUse ? "󰖩" : (signal > 75 ? "󰤨" : (signal > 50 ? "󰤥" : (signal > 25 ? "󰤢" : "󰤟")))
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                            color: inUse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                        }

                        Column {
                            Layout.fillWidth: true; spacing: 1
                            RowLayout {
                                spacing: 6
                                Text { text: ssid; color: inUse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "white"); font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; Layout.maximumWidth: wifiCard.width - 150 }
                                Text { visible: !inUse && isSaved && !isCurrentlyConnecting; text: "󰌾 Saved"; font.pixelSize: 10; color: Theme.colors.accent ?? "#7aa2f7" }
                                Text { visible: isCurrentlyConnecting; text: "• Connecting..."; font.pixelSize: 11; font.bold: true; color: Theme.colors.accent ?? "#7aa2f7" }
                            }
                            Text {
                                text: isCurrentlyConnecting ? "Authenticating credentials..." : ((security !== "" && security !== "--" ? "Secured" : "Open") + " • " + signal + "%")
                                color: isCurrentlyConnecting ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            visible: inUse
                            Layout.preferredWidth: 80; Layout.preferredHeight: 26; radius: 6; color: "#f44336"
                            Text { anchors.centerIn: parent; text: "Disconnect"; color: "white"; font.bold: true; font.pixelSize: 11 }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    wifiDisconnecter.command = ["sh", "-c", "nmcli connection down id '" + ssid + "' || nmcli dev disconnect wlan0"];
                                    wifiDisconnecter.running = true;
                                }
                            }
                        }

                        Text { visible: !inUse; text: isExpanded ? "󰅃" : "󰅀"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.colors.text_secondary ?? "#565f89" }
                    }

                    // Drawer Actions
                    RowLayout {
                        Layout.fillWidth: true; visible: !inUse && isExpanded && !showPassword; spacing: 6

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 6
                            color: isCurrentlyConnecting ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.accent ?? "#7aa2f7")
                            Text { anchors.centerIn: parent; text: isCurrentlyConnecting ? "Connecting..." : "Connect"; color: isCurrentlyConnecting ? "white" : (Theme.colors.bg ?? "#16161e"); font.bold: true; font.pixelSize: 11 }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !isCurrentlyConnecting
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
                            Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 6; color: Theme.colors.hover_bg ?? "#24283b"
                            border.width: 1; border.color: Theme.colors.border ?? "#16161e"
                            Text { anchors.centerIn: parent; text: "Forget"; color: Theme.colors.text_primary ?? "white"; font.bold: true; font.pixelSize: 11 }
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
                            Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 6; color: Theme.colors.hover_bg ?? "#24283b"
                            border.width: 1; border.color: Theme.colors.border ?? "#16161e"
                            Text { anchors.centerIn: parent; text: "Trust"; color: Theme.colors.text_primary ?? "white"; font.bold: true; font.pixelSize: 11 }
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

                    // Password Field
                    ColumnLayout {
                        Layout.fillWidth: true; visible: !inUse && isExpanded && showPassword; spacing: 4

                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            TextField {
                                id: passField
                                Layout.fillWidth: true; Layout.preferredHeight: 28
                                placeholderText: "Enter Password..."
                                placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                                echoMode: TextInput.Password; color: Theme.colors.text_primary ?? "white"
                                font.pixelSize: 12; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                enabled: !isCurrentlyConnecting
                                background: Rectangle {
                                    color: Theme.colors.bg ?? "#16161e"; radius: 6; border.width: 1
                                    border.color: hasError ? "#f44336" : (passField.activeFocus ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e"))
                                }
                                Keys.onReturnPressed: joinBtn.submit()
                                Keys.onEnterPressed: joinBtn.submit()
                            }

                            Rectangle {
                                id: joinBtn
                                Layout.preferredWidth: isCurrentlyConnecting ? 74 : 46; Layout.preferredHeight: 28; radius: 6
                                color: isCurrentlyConnecting ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.accent ?? "#7aa2f7")
                                function submit() { if (!isCurrentlyConnecting) wifiMaster.initiateConnection(ssid, passField.text, index); }
                                Text { anchors.centerIn: parent; text: isCurrentlyConnecting ? "Joining..." : "Join"; color: isCurrentlyConnecting ? "white" : (Theme.colors.bg ?? "#16161e"); font.bold: true; font.pixelSize: 11 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !isCurrentlyConnecting; onClicked: joinBtn.submit() }
                            }

                            Rectangle {
                                Layout.preferredWidth: 32; Layout.preferredHeight: 28; radius: 6; color: Theme.colors.hover_bg ?? "#24283b"
                                enabled: !isCurrentlyConnecting
                                Text { anchors.centerIn: parent; text: "✕"; color: Theme.colors.text_secondary ?? "#565f89"; font.pixelSize: 11 }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wifiModel.setProperty(index, "showPassword", false);
                                        wifiModel.setProperty(index, "hasError", false);
                                        wifiModel.setProperty(index, "errorMsg", "");
                                    }
                                }
                            }
                        }

                        Text { visible: hasError; text: "⚠ " + errorMsg; color: "#f44336"; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }

                MouseArea {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 44
                    enabled: !inUse && !isCurrentlyConnecting
                    cursorShape: Qt.PointingHandCursor
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

    // Hotspot Tab View
    ColumnLayout {
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: wifiMaster.activeTab === "hotspot"
        spacing: 12

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 10
            color: Theme.colors.card_bg ?? "#1f2335"
            border.width: 1; border.color: wifiMaster.hotspotActive ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 14

                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: wifiMaster.hotspotActive ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.hover_bg ?? "#24283b")
                        Text { anchors.centerIn: parent; text: "󰖪"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: wifiMaster.hotspotActive ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_secondary ?? "#565f89") }
                    }
                    Column {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Access Point Hotspot"; font.bold: true; font.pixelSize: 14; color: Theme.colors.text_primary ?? "white" }
                        Text { text: wifiMaster.hotspotActive ? "Broadcasting live" : "Inactive"; font.pixelSize: 11; color: wifiMaster.hotspotActive ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89") }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "Hotspot Name (SSID)"; font.pixelSize: 11; font.bold: true; color: Theme.colors.text_secondary ?? "#565f89" }
                    TextField {
                        id: hotspotSsidField
                        Layout.fillWidth: true; Layout.preferredHeight: 32
                        text: wifiMaster.hotspotSsid
                        color: Theme.colors.text_primary ?? "white"; font.pixelSize: 13; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                        onTextChanged: wifiMaster.hotspotSsid = text
                        background: Rectangle { color: Theme.colors.bg ?? "#16161e"; radius: 6; border.width: 1; border.color: hotspotSsidField.activeFocus ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e") }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "Password (Min 8 Characters)"; font.pixelSize: 11; font.bold: true; color: Theme.colors.text_secondary ?? "#565f89" }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        TextField {
                            id: hotspotPassField
                            Layout.fillWidth: true; Layout.preferredHeight: 32
                            text: wifiMaster.hotspotPass
                            echoMode: wifiMaster.hotspotShowPassword ? TextInput.Normal : TextInput.Password
                            color: Theme.colors.text_primary ?? "white"; font.pixelSize: 13; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onTextChanged: wifiMaster.hotspotPass = text
                            background: Rectangle { color: Theme.colors.bg ?? "#16161e"; radius: 6; border.width: 1; border.color: hotspotPassField.activeFocus ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e") }
                        }
                        Rectangle {
                            Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 6; color: Theme.colors.hover_bg ?? "#24283b"
                            Text { anchors.centerIn: parent; text: wifiMaster.hotspotShowPassword ? "󰈈" : "󰈉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.colors.text_primary ?? "white" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiMaster.hotspotShowPassword = !wifiMaster.hotspotShowPassword }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 8
                    color: wifiMaster.hotspotActive ? "#f44336" : (Theme.colors.accent ?? "#7aa2f7")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: wifiMaster.hotspotActive ? "󰐥" : "󰖪"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: wifiMaster.hotspotActive ? "white" : (Theme.colors.bg ?? "#16161e") }
                        Text { text: wifiMaster.hotspotActive ? "Stop Hotspot" : "Start Hotspot"; font.bold: true; font.pixelSize: 13; color: wifiMaster.hotspotActive ? "white" : (Theme.colors.bg ?? "#16161e") }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifiMaster.toggleHotspot(!wifiMaster.hotspotActive) }
                }
            }
        }
    }
}
