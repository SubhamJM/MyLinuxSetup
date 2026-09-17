import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import "../"

Item {
    id: dash
    Layout.fillWidth: true
    Layout.fillHeight: true

    property bool netIslandExpanded: false
    property bool powerIslandExpanded: false
    property bool isIslandActive: btIslandExpanded || powerIslandExpanded || netIslandExpanded || root.isNotifPopupActive || root.isWorkspacePeeking

    readonly property string currentIslandType: {
        if (root.isNotifPopupActive) return "notif";
        if (btIslandExpanded) return "bluetooth";
        if (powerIslandExpanded) return "power";
        if (netIslandExpanded) return "net";
        if (root.isWorkspacePeeking) return "workspace";
        return "";
    }

    property string displayedIslandType: ""

    onCurrentIslandTypeChanged: {
        if (currentIslandType !== "") {
            displayedIslandType = currentIslandType;
        }
    }

    property int activeIslandWidth: {
        if (displayedIslandType === "notif" || root.isNotifPopupActive) {
            var textW = Math.max(notifSummaryText.implicitWidth, notifBodyText.implicitWidth);
            return Math.min(520, Math.max(260, textW + 80));
        }
        if (displayedIslandType === "workspace" || root.isWorkspacePeeking) {
            return Math.max(136, wsIslandRow.implicitWidth + 36);
        }
        if (displayedIslandType === "bluetooth" || btIslandExpanded) return btPopupRow.implicitWidth + 36;
        if (displayedIslandType === "power" || powerIslandExpanded) return powerPopupRow.implicitWidth + 36;
        if (displayedIslandType === "net" || netIslandExpanded) return netPopupRow.implicitWidth + 36;
        return 120;
    }

    implicitWidth: {
        if (isIslandActive) return activeIslandWidth;
        if (root.activeMode === "hover") {
            return Math.max(160, dashRow.implicitWidth + 32);
        }
        if (isMediaPlaying && root.activeMode === "idle") return Math.max(120, centerRow.implicitWidth + 48);
        return 120;
    }

    readonly property var activePlayer: {
        if (typeof Mpris === "undefined" || !Mpris.players) return null;
        var list = Mpris.players.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing) return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    property string rawPlaybackStatus: ""
    property bool rawIsMediaPlaying: false
    property string rawSongTitle: ""
    property string rawSongArtist: ""
    property string rawAlbumArt: ""

    property bool isMediaPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : rawIsMediaPlaying
    property string playbackStatus: activePlayer ? (isMediaPlaying ? "Playing" : "Paused") : rawPlaybackStatus
    property bool showMusicInfo: false
    property string currentSongArtist: {
        if (activePlayer) {
            if (Array.isArray(activePlayer.trackArtists)) return activePlayer.trackArtists.join(", ");
            if (typeof activePlayer.trackArtists === "string") return activePlayer.trackArtists;
            if (typeof activePlayer.trackArtist === "string") return activePlayer.trackArtist;
        }
        return rawSongArtist;
    }
    property string currentAlbumArt: activePlayer ? (activePlayer.artUrl || "") : rawAlbumArt

    property bool isMusicDisplayed: (showMusicInfo || isMediaPlaying) && (activePlayer || rawSongTitle !== "") && root.activeMode === "idle"

    onIsMediaPlayingChanged: {
        if (!isMediaPlaying) showMusicInfo = false;
    }

    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    Process {
        id: mprisPoller
        command: ["sh", "-c", "timeout 1.8 playerctl metadata --format '{{status}}\n{{title}}\n{{artist}}\n{{mpris:artUrl}}' 2>/dev/null || echo -e '\n\n\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (dash.activePlayer) return;
                var lines = this.text.split("\n");
                var status = lines[0] ? lines[0].trim() : "";
                dash.rawPlaybackStatus = status;
                dash.rawIsMediaPlaying = (status === "Playing");
                dash.rawSongTitle = lines[1] ? lines[1].trim() : "";
                dash.rawSongArtist = lines[2] ? lines[2].trim() : "";
                
                var art = lines[3] ? lines[3].trim() : "";
                if (art.startsWith("file://") || art.length > 0) {
                    dash.rawAlbumArt = art;
                } else {
                    dash.rawAlbumArt = "";
                }
            }
        }
    }
    Timer {
        interval: 3000
        running: !dash.activePlayer
        repeat: true
        onTriggered: {
            if (!mprisPoller.running) {
                mprisPoller.running = true;
            }
        }
    }

    property string activeNetType: "wifi"
    property string activeNetName: ""
    property int activeNetSignal: 0

    readonly property var activeBtDevice: {
        if (typeof Bluetooth === "undefined" || !Bluetooth.devices) return null;
        var devs = Bluetooth.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].connected) return devs[i];
        }
        return null;
    }

    property bool rawBtConnected: false
    property string rawBtDeviceName: ""
    property bool btConnected: activeBtDevice ? true : rawBtConnected
    property string btDeviceName: activeBtDevice ? (activeBtDevice.name || "") : rawBtDeviceName

    property bool triggerNetText: false
    property bool triggerBtText: false

    property bool isNetInitialized: false
    onActiveNetTypeChanged: {
        if (dash.isNetInitialized) {
            dash.netIslandExpanded = true;
            netPopupTimer.restart();
        }
    }
    onActiveNetNameChanged: { triggerNetText = true; netTextTimer.restart(); }
    onBtConnectedChanged: { 
        triggerBtText = true; btTextTimer.restart(); 
        if (btConnected) {
            dash.btIslandExpanded = true;
            btPopupTimer.restart();
            btBatPopupFetcher.command = ["sh", "-c", "bluetoothctl info | grep 'Battery Percentage'"];
            btBatPopupFetcher.running = true;
        }
    }

    property bool btIslandExpanded: false
    property string btIslandBattery: ""
    Timer { id: btPopupTimer; interval: NotchConfig.timerBtPopup; onTriggered: dash.btIslandExpanded = false }
    Timer { id: powerPopupTimer; interval: NotchConfig.timerPowerPopup; onTriggered: dash.powerIslandExpanded = false }
    Timer { id: netPopupTimer; interval: NotchConfig.timerNetPopup; onTriggered: dash.netIslandExpanded = false }

    Timer { id: netTextTimer; interval: NotchConfig.timerIslandText; onTriggered: triggerNetText = false }
    Timer { id: btTextTimer; interval: NotchConfig.timerIslandText; onTriggered: triggerBtText = false }

    Connections {
        target: typeof battMod !== "undefined" ? battMod : null
        function onIsChargingChanged() {
            if (battMod.isCharging) {
                dash.powerIslandExpanded = true;
                powerPopupTimer.restart();
            }
        }
    }

    Process {
        id: btBatPopupFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var batMatch = this.text.trim().match(/Battery Percentage:\s*(?:0x[0-9a-fA-F]+\s*)?\(([^)]+)\)/);
                if (batMatch && batMatch[1]) {
                    dash.btIslandBattery = batMatch[1] + "%";
                } else {
                    dash.btIslandBattery = "";
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!netPoller.running) netPoller.running = true;
            if (!dash.activeBtDevice && !btPoller.running) btPoller.running = true;
        }
    }

    Process {
        id: netPoller
        command: ["sh", "-c", "nmcli -t -f TYPE,CONNECTION,STATE dev | grep connected | head -n 1; nmcli -t -f IN-USE,SIGNAL dev wifi list 2>/dev/null | grep '^\\*' | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var line = lines[0] ? lines[0].trim() : "";
                var sigStr = lines[1] ? lines[1].trim() : "0";
                
                if (line.length > 0) {
                    var parts = line.split(":");
                    if (parts.length >= 3) {
                        if (parts[0].indexOf("ethernet") !== -1) dash.activeNetType = "eth";
                        else if (parts[0].indexOf("wifi") !== -1 || parts[0].indexOf("wireless") !== -1) dash.activeNetType = "wifi";
                        dash.activeNetName = parts[1];
                        dash.activeNetSignal = parseInt(sigStr) || 0;
                    }
                } else {
                    dash.activeNetType = "wifi";
                    dash.activeNetName = "";
                    dash.activeNetSignal = 0;
                }
                dash.isNetInitialized = true;
            }
        }
    }

    Process {
        id: btPoller
        command: ["sh", "-c", "bluetoothctl devices Connected | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (dash.activeBtDevice) return;
                var line = this.text.trim();
                if (line.indexOf("Device") !== -1) {
                    dash.rawBtConnected = true;
                    var parts = line.split(" ");
                    if (parts.length >= 3) {
                        dash.rawBtDeviceName = parts.slice(2).join(" ");
                    }
                } else {
                    dash.rawBtConnected = false;
                    dash.rawBtDeviceName = "";
                }
            }
        }
    }

    function startOcr() {
        if (!ocrRunner.running) {
            ocrRunner.running = true;
        }
    }

    Process {
        id: ocrRunner
        running: false
        command: ["/home/ricing/.config/quickshell/scripts/snip_ocr.sh"]
    }

    // Stable workspace model tracking to prevent delegate teardown during animations
    property var workspaceIds: [1]

    function refreshWorkspaceIds() {
        if (typeof Hyprland === "undefined" || !Hyprland.workspaces) return;
        var raw = Hyprland.workspaces.values.filter(function(w) { return w.id > 0; });
        var focusedId = (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0)
            ? Hyprland.focusedWorkspace.id
            : 1;
        var ids = [];
        var found = false;
        for (var i = 0; i < raw.length; i++) {
            ids.push(raw[i].id);
            if (raw[i].id === focusedId) found = true;
        }
        if (!found) ids.push(focusedId);
        ids.sort(function(a, b) { return a - b; });

        if (ids.length !== dash.workspaceIds.length) {
            dash.workspaceIds = ids;
            return;
        }
        for (var j = 0; j < ids.length; j++) {
            if (ids[j] !== dash.workspaceIds[j]) {
                dash.workspaceIds = ids;
                return;
            }
        }
    }

    Component.onCompleted: refreshWorkspaceIds()

    Connections {
        target: typeof Hyprland !== "undefined" ? Hyprland : null
        function onRawEvent(event) {
            var evName = (typeof event === "object" && event !== null) ? event.name : event;
            if (evName === "workspace" || evName === "focusedmon" || evName === "workspacev2" || evName === "createworkspace" || evName === "destroyworkspace") {
                dash.refreshWorkspaceIds();
            }
        }
    }

    // Dynamic Island Container
    Item {
        id: islandContainer
        anchors.fill: parent
        opacity: dash.isIslandActive ? 1.0 : 0.0
        scale: dash.isIslandActive ? 1.0 : 0.92
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }

        onOpacityChanged: {
            if (opacity <= 0.01 && !dash.isIslandActive) {
                dash.displayedIslandType = "";
            }
        }

        // Pop-up Notification Row (fixed layout with explicit positioning)
        RowLayout {
            id: notifPopupRow
            anchors.centerIn: parent
            spacing: 8
            visible: dash.displayedIslandType === "notif"

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: Qt.rgba((Theme.colors.accent ?? "#7aa2f7").r, (Theme.colors.accent ?? "#7aa2f7").g, (Theme.colors.accent ?? "#7aa2f7").b, 0.2)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.colors.accent ?? "#7aa2f7"
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    id: notifSummaryText
                    text: root.notifPopupSummary
                    font.family: "Inter"
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.colors.text_primary ?? "white"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 380
                }

                Text {
                    id: notifBodyText
                    text: root.notifPopupBody
                    font.family: "Inter"
                    font.pixelSize: 10
                    color: Theme.colors.text_secondary ?? "#565f89"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 380
                    visible: text !== ""
                }
            }
        }

        MouseArea {
            anchors.fill: notifPopupRow
            enabled: dash.displayedIslandType === "notif"
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                notifPopupTimer.stop();
                root.notifPopupSummary = "";
                root.notifPopupBody = "";
                root.switchMode("notifications", true);
            }
        }

        // Bluetooth Connected Alert
        Row {
            id: btPopupRow
            anchors.centerIn: parent
            spacing: 8
            visible: dash.displayedIslandType === "bluetooth"

            Text { 
                text: "󰂱"
                font.family: "JetBrainsMono Nerd Font"
                color: Theme.colors.accent ?? "#7aa2f7"
                font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
            }
            Text { 
                text: dash.btDeviceName
                color: "white"
                font.pixelSize: 14
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text { 
                text: dash.btIslandBattery
                color: "#565f89"
                font.pixelSize: 14
                font.bold: true
                visible: dash.btIslandBattery !== ""
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Power Notification (MagSafe style)
        Row {
            id: powerPopupRow
            anchors.centerIn: parent
            spacing: 12
            visible: dash.displayedIslandType === "power"
            
            Item {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 20; height: 20
                    radius: 10
                    color: "transparent"
                    border.width: 3
                    border.color: "#4caf50"
                    opacity: dash.powerIslandExpanded ? 1.0 : 0.0
                    scale: dash.powerIslandExpanded ? 1.0 : 0.5
                    
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }
                    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "󰚥"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                    color: "#4caf50"
                }
            }

            Text {
                text: typeof battMod !== "undefined" ? battMod.batteryLevel + "% Charging" : "Charging"
                color: "#4caf50"
                font.pixelSize: 14; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Network Handoff Notification
        Row {
            id: netPopupRow
            anchors.centerIn: parent
            spacing: 8
            visible: dash.displayedIslandType === "net"
            
            Text {
                text: dash.activeNetType === "eth" ? "󰈀" : "󰤨"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                color: Theme.colors.accent ?? "#7aa2f7"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: dash.activeNetType === "eth" ? "Switched to Wired" : "Switched to WiFi"
                color: Theme.colors.text_primary ?? "white"
                font.pixelSize: 14; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }


        // Workspace Switch Island Row (minimalist dot-to-pill indicator)
        Row {
            id: wsIslandRow
            anchors.centerIn: parent
            spacing: 8
            visible: dash.displayedIslandType === "workspace"

            Repeater {
                model: dash.workspaceIds

                delegate: Item {
                    id: indicatorItem
                    property int wsId: modelData
                    property bool isFocused: typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && (wsId === Hyprland.focusedWorkspace.id)

                    width: isFocused ? 26 : 8
                    height: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        id: pillShape
                        anchors.fill: parent
                        radius: 4
                        color: indicatorItem.isFocused
                            ? (Theme.colors.accent ?? "#7aa2f7")
                            : (dotMouse.containsMouse ? (Theme.colors.text_primary ?? "#c0caf5") : Qt.rgba(1, 1, 1, 0.28))

                        Behavior on color {
                            ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }

                        // Soft glow ring for active workspace pill
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: 5
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.colors.accent ?? "#7aa2f7"
                            opacity: indicatorItem.isFocused ? 0.35 : 0.0
                            visible: opacity > 0.001
                            Behavior on opacity {
                                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    MouseArea {
                        id: dotMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (typeof Hyprland !== "undefined") {
                                Hyprland.dispatch("hl.dsp.focus({ workspace = " + indicatorItem.wsId + " })");
                            }
                        }
                    }
                }
            }
        }
    }

    // Default Persistent Bar Row
    Row {
        id: dashRow
        anchors.centerIn: parent
        spacing: 16
        opacity: dash.isIslandActive ? 0.0 : 1.0
        scale: dash.isIslandActive ? 0.92 : 1.0
        visible: opacity > 0.001
        layer.enabled: true
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }

        // Workspaces (left of clock)
        Row {
            id: leftGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: root.activeMode === "hover"
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Repeater {
                model: typeof Hyprland !== "undefined" && Hyprland.workspaces
                    ? Hyprland.workspaces.values.filter(function(w) { return w.id > 0; })
                    : []
                delegate: Rectangle {
                    width: 26; height: 26; radius: 8
                    property bool isFocused: typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && (modelData.id === Hyprland.focusedWorkspace.id)
                    color: isFocused ? (Theme.colors.accent ?? "#7aa2f7") : (wsMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent")
                    border.width: wsMouse.containsMouse && !isFocused ? 1 : 0
                    border.color: Theme.colors.border_hover ?? "#7aa2f7"
                    scale: isFocused ? 1.06 : 1.0
                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.id
                        color: parent.isFocused ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                        font.pixelSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof Hyprland !== "undefined") Hyprland.dispatch(`hl.dsp.focus({workspace = ${modelData.id}})`);
                        }
                    }
                }
            }
        }

        // Divider — workspaces | clock
        Rectangle {
            width: 1
            height: 18
            radius: 0.5
            color: Theme.colors.text_secondary ?? "#565f89"
            opacity: leftGroup.visible ? 0.25 : 0.0
            visible: leftGroup.visible
            anchors.verticalCenter: parent.verticalCenter
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        // Date & Time / Music Info
        Item {
            id: centerItem
            width: centerRow.implicitWidth
            height: 26

            // Reusable visualizer component
            component EqualizerVisualizer: Row {
                id: eqRoot
                property bool mirrored: false
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                opacity: (dash.isMediaPlaying && root.activeMode === "idle") ? 1.0 : 0.0
                
                property int targetWidth: (dash.isMediaPlaying && root.activeMode === "idle") ? (4 * 2.5 + 3 * 2) : 0
                width: targetWidth
                visible: width > 0
                clip: true
                
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                readonly property var barHeights: [8, 14, 10, 13]
                readonly property var barDurations: [340, 260, 310, 290]

                Repeater {
                    model: 4
                    delegate: Rectangle {
                        width: 2.5
                        radius: 1.25
                        color: Theme.colors.accent ?? "#7aa2f7"
                        anchors.verticalCenter: parent.verticalCenter

                        // Mirror bar index pattern on the right side for symmetrical bouncing
                        property int effectiveIdx: eqRoot.mirrored ? (3 - index) : index
                        property real targetA: eqRoot.barHeights[effectiveIdx]
                        property real targetB: eqRoot.barHeights[(effectiveIdx + 2) % 4]

                        height: targetA

                        SequentialAnimation on height {
                            running: dash.isMediaPlaying && root.activeMode === "idle"
                            loops: Animation.Infinite
                            NumberAnimation { to: targetB; duration: eqRoot.barDurations[effectiveIdx]; easing.type: Easing.InOutSine }
                            NumberAnimation { to: targetA; duration: eqRoot.barDurations[(effectiveIdx + 1) % 4]; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: 8

                // Left Audio Visualizer
                EqualizerVisualizer {
                    mirrored: false
                }

                // Album Art
                Rectangle {
                    id: albumArtRect
                    width: (dash.isMusicDisplayed && dash.currentAlbumArt !== "") ? 18 : 0
                    height: 18
                    radius: 5
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#24283b"
                    visible: width > 0

                    Image {
                        id: albumArtImage
                        anchors.fill: parent
                        source: dash.currentAlbumArt
                        fillMode: Image.PreserveAspectCrop
                        opacity: status === Image.Ready ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.colors.accent ?? "#7aa2f7"
                        opacity: 0.35
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (dash.activePlayer) dash.activePlayer.playPause();
                            else Quickshell.execDetached(["playerctl", "play-pause"]);
                        }
                    }
                }

                // Music Icon
                Text {
                    id: musicIcon
                    text: "󰎆"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Theme.colors.accent ?? "#7aa2f7"
                    visible: dash.isMusicDisplayed && dash.currentAlbumArt === ""
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: musicIcon.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.5; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.5; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (dash.activePlayer) dash.activePlayer.playPause();
                            else Quickshell.execDetached(["playerctl", "play-pause"]);
                        }
                    }
                }

                // Date text
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    color: Theme.colors.text_secondary ?? "#565f89"
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.bold: true
                    visible: root.activeMode === "hover"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Clock
                Text {
                    id: clockText
                    text: {
                        var h = clock.date.getHours() % 12 || 12;
                        var m = (clock.date.getMinutes() < 10 ? "0" : "") + clock.date.getMinutes();
                        return (h < 10 ? "0" : "") + h + ":" + m;
                    }
                    color: Theme.colors.text_primary ?? "white"
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.bold: true
                    font.features: { "tnum": 1 }
                    renderType: Text.QtRendering
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Right Audio Visualizer (Mirrored)
                EqualizerVisualizer {
                    mirrored: true
                }

                // Separator dot
                Text {
                    text: "·"
                    color: Theme.colors.text_secondary ?? "#565f89"
                    font.pixelSize: 14
                    font.bold: true
                    opacity: dash.isMusicDisplayed ? 0.7 : 0.0
                    visible: opacity > 0.01
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }

                // Song Title / Artist
                Item {
                    id: songTextItem
                    width: dash.isMusicDisplayed ? songRow.implicitWidth : 0
                    height: 18
                    clip: true
                    opacity: dash.isMusicDisplayed ? 1.0 : 0.0
                    visible: width > 0
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }

                    Row {
                        id: songRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            text: dash.currentSongTitle || ""
                            color: Theme.colors.text_primary ?? "white"
                            font.family: "Inter"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.1
                        }
                        Text {
                            text: dash.currentSongArtist
                            visible: dash.currentSongArtist !== ""
                            color: Theme.colors.text_secondary ?? "#565f89"
                            font.family: "Inter"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.switchMode("music", true);
                        }
                        onWheel: (wheel) => {
                            wheel.accepted = true;
                            if (wheel.angleDelta.y < 0) {
                                if (dash.activePlayer) dash.activePlayer.next();
                                else Quickshell.execDetached(["playerctl", "next"]);
                            } else if (wheel.angleDelta.y > 0) {
                                if (dash.activePlayer) dash.activePlayer.previous();
                                else Quickshell.execDetached(["playerctl", "previous"]);
                            }
                        }
                    }
                }

                // Recording Indicator
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 3.5
                    color: "#f44336"
                    visible: root.isScreenRecording

                    SequentialAnimation on opacity {
                        running: root.isScreenRecording
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.2; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.2; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
                }
            }

            MouseArea {
                id: timeMouse
                anchors.fill: parent
                hoverEnabled: root.activeMode === "hover"
                enabled: root.activeMode === "hover"
                cursorShape: root.activeMode === "hover" ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.isScreenRecording) {
                        root.switchMode("recorder");
                    } else if (root.activeMode === "hover") {
                        root.switchMode("calendar");
                    }
                }
            }
        }

        // Divider — clock | tray
        Rectangle {
            width: 1
            height: 18
            radius: 0.5
            color: Theme.colors.text_secondary ?? "#565f89"
            opacity: leftGroup.visible ? 0.25 : 0.0
            visible: leftGroup.visible
            anchors.verticalCenter: parent.verticalCenter
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        // System Tray Container
        Row {
            id: rightGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: root.activeMode === "hover"
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }


            Rectangle {
                width: 26; height: 26; radius: 8
                color: utilMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: utilMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: "󱊖"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                    color: Theme.colors.text_primary ?? "#c0caf5"
                }
                MouseArea {
                    id: utilMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("utility", true)
                }
            }

            // Battery
            Rectangle {
                width: battRow.implicitWidth + 16; height: 26; radius: 8
                color: battMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: battMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                BatteryPill {
                    id: battRow
                    anchors.centerIn: parent
                }
                MouseArea {
                    id: battMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("battery")
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
