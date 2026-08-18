import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../"

Item {
    id: dash
    Layout.fillWidth: true
    Layout.fillHeight: true

    property bool netIslandExpanded: false
    property bool powerIslandExpanded: false
    property bool isIslandActive: btIslandExpanded || powerIslandExpanded || netIslandExpanded
    property int activeIslandWidth: {
        if (btIslandExpanded) return btPopupRow.implicitWidth + 36;
        if (powerIslandExpanded) return powerPopupRow.implicitWidth + 36;
        if (netIslandExpanded) return netPopupRow.implicitWidth + 36;
        return 120;
    }

    implicitWidth: {
        if (isIslandActive) return activeIslandWidth;
        if (root.activeMode === "hover") {
            var w = centerRow.implicitWidth;
            if (leftGroup.visible) w += leftGroup.implicitWidth + 16;
            if (rightGroup.visible) w += rightGroup.implicitWidth + 16;
            return Math.max(160, w + 32);
        }
        if (isMediaPlaying && root.activeMode === "idle") return Math.max(120, centerRow.implicitWidth + 48);
        return 120;
    }

    

    property string playbackStatus: ""
    property bool isMediaPlaying: false
    property bool showMusicInfo: false
    property string currentSongTitle: ""
    property string currentSongArtist: ""

    property string currentAlbumArt: ""
    property bool isMusicDisplayed: showMusicInfo && isMediaPlaying && root.activeMode === "idle"

    // Caelestia-flavoured "emphasized decelerate" motion curve — smooth glide, no bounce.
    // (Material 3 emphasized-decelerate: cubic-bezier(0.05, 0.7, 0.1, 1))
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    Process {
        id: mprisPoller
        command: ["sh", "-c", "timeout 1.8 playerctl metadata --format '{{status}}\n{{title}}\n{{artist}}\n{{mpris:artUrl}}' 2>/dev/null || echo -e '\n\n\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var status = lines[0] ? lines[0].trim() : "";
                dash.playbackStatus = status;
                dash.isMediaPlaying = (status === "Playing");
                dash.currentSongTitle = lines[1] ? lines[1].trim() : "";
                dash.currentSongArtist = lines[2] ? lines[2].trim() : "";
                
                var art = lines[3] ? lines[3].trim() : "";
                if (art.startsWith("file://") || art.length > 0) {
                    dash.currentAlbumArt = art;
                } else {
                    dash.currentAlbumArt = "";
                }
                
                if (!dash.isMediaPlaying) dash.showMusicInfo = false;
            }
        }
    }
    Timer {
        interval: 1000
        running: true
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
    property bool btConnected: false
    property string btDeviceName: ""

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
    Timer { id: btPopupTimer; interval: 4000; onTriggered: dash.btIslandExpanded = false }

    Timer { id: powerPopupTimer; interval: 4000; onTriggered: dash.powerIslandExpanded = false }
    
    Timer { id: netPopupTimer; interval: 4000; onTriggered: dash.netIslandExpanded = false }

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

    Timer { id: netTextTimer; interval: 3500; onTriggered: triggerNetText = false }
    Timer { id: btTextTimer; interval: 3500; onTriggered: triggerBtText = false }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netPoller.running = true;
            btPoller.running = true;
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
                var line = this.text.trim();
                if (line.indexOf("Device") !== -1) {
                    dash.btConnected = true;
                    var parts = line.split(" ");
                    if (parts.length >= 3) {
                        dash.btDeviceName = parts.slice(2).join(" ");
                    }
                } else {
                    dash.btConnected = false;
                    dash.btDeviceName = "";
                }
            }
        }
    }

    // Island Container
    Row {
        id: islandContainer
        anchors.centerIn: parent
        opacity: dash.isIslandActive ? 1.0 : 0.0
        scale: dash.isIslandActive ? 1.0 : 0.9
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.BezierCurve; easing.bezierCurve: dash.motionCurve } }
        Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.BezierCurve; easing.bezierCurve: dash.motionCurve } }

        Row {
            id: btPopupRow
            spacing: 8
            visible: dash.btIslandExpanded

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
            spacing: 12
            visible: dash.powerIslandExpanded && !dash.btIslandExpanded
            
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
                    
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.BezierCurve; easing.bezierCurve: dash.motionCurve } }
                    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.BezierCurve; easing.bezierCurve: dash.motionCurve } }
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
            spacing: 8
            visible: dash.netIslandExpanded && !dash.powerIslandExpanded && !dash.btIslandExpanded
            
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
    }

    Row {
        id: dashRow
        anchors.centerIn: parent
        spacing: 16
        opacity: dash.isIslandActive ? 0.0 : 1.0
        scale: dash.isIslandActive ? 0.92 : 1.0
        visible: opacity > 0.01
        layer.enabled: true
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.BezierCurve; easing.bezierCurve: dash.motionCurve } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.BezierCurve; easing.bezierCurve: dash.motionCurve } }

        // Workspaces (left of clock)
        Row {
            id: leftGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: root.activeMode === "hover"
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Repeater {
                // Special/scratchpad Hyprland workspaces use negative ids (e.g. -98, -99)
                // and shouldn't be rendered as regular workspace pills.
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
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.BezierCurve; easing.bezierCurve: dash.motionCurve } }

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

        // Date & Time / Music Info
        Item {
            id: centerItem
            width: centerRow.implicitWidth
            height: 26

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: 8

                // Audio Visualizer (5 bars, staggered)
                Row {
                    id: audioVisualizer
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: (dash.isMediaPlaying && root.activeMode === "idle") ? 1.0 : 0.0
                    
                    property int targetWidth: (dash.isMediaPlaying && root.activeMode === "idle") ? (5 * 2.5 + 4 * 2) : 0 // 5 bars of 2.5px width, 4 gaps of 2px
                    width: targetWidth
                    visible: width > 0
                    clip: true
                    
                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                    property var barHeights: [10, 14, 8, 12, 6]
                    property var barDurations: [380, 280, 340, 310, 360]

                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            width: 2.5
                            radius: 1.25
                            color: Theme.colors.accent ?? "#7aa2f7"
                            anchors.verticalCenter: parent.verticalCenter

                            property real targetA: audioVisualizer.barHeights[index]
                            property real targetB: audioVisualizer.barHeights[(index + 2) % 5]

                            height: targetA

                            SequentialAnimation on height {
                                running: dash.isMediaPlaying && root.activeMode === "idle"
                                loops: Animation.Infinite
                                NumberAnimation { to: targetB; duration: audioVisualizer.barDurations[index]; easing.type: Easing.InOutSine }
                                NumberAnimation { to: targetA; duration: audioVisualizer.barDurations[(index + 3) % 5]; easing.type: Easing.InOutSine }
                            }
                        }
                    }
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
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.BezierCurve; easing.bezierCurve: dash.motionCurve } }

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
                }

                // Music Icon (fallback when no album art) — gently pulses while playing
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
                }

                // Date text (only in hover mode)
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    color: Theme.colors.text_secondary ?? "#565f89"
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.bold: true
                    visible: root.activeMode === "hover"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Clock — always visible as an anchor point, sitting symmetrically
                // between the visualizer/artwork on one side and the song info on the other
                Text {
                    id: clockText
                    text: Qt.formatDateTime(clock.date, "hh:mm AP")
                    color: Theme.colors.text_primary ?? "white"
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.bold: true
                    font.features: { "tnum": 1 }
                    renderType: Text.QtRendering
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Small separator dot, only present while song info is shown
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

                // Song title / artist — separate styling so the title reads
                // stronger than the artist, with its own font and gentle elide
                Item {
                    id: songTextItem
                    width: dash.isMusicDisplayed ? songRow.implicitWidth : 0
                    height: 18
                    clip: true
                    opacity: dash.isMusicDisplayed ? 1.0 : 0.0
                    visible: width > 0
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.BezierCurve; easing.bezierCurve: dash.motionCurve } }
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.BezierCurve; easing.bezierCurve: dash.motionCurve } }

                    Row {
                        id: songRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        // No width clamp / elide — show the full title and artist
                        Text {
                            text: dash.currentSongTitle
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
                }


                // Recording Dot
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

        // System Tray Container (right of clock)
        Row {
            id: rightGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: root.activeMode === "hover"
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Rectangle {
                width: 26; height: 26; radius: 8
                color: wifiMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: wifiMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: dash.activeNetType === "eth" ? "󰈀" : (dash.activeNetSignal > 75 ? "󰤨" : (dash.activeNetSignal > 50 ? "󰤥" : (dash.activeNetSignal > 25 ? "󰤢" : "󰤟")))
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                    color: Theme.colors.text_primary ?? "#c0caf5"
                }
                MouseArea {
                    id: wifiMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("wifi")
                }
            }

            Rectangle {
                width: 26; height: 26; radius: 8
                color: btMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: btMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: dash.btConnected ? "󰂱" : "󰂯"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                    color: Theme.colors.text_primary ?? "#c0caf5"
                }
                MouseArea {
                    id: btMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("bluetooth")
                }
            }

            Rectangle {
                width: 26; height: 26; radius: 8
                color: recMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: recMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: "󰕧"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                    color: Theme.colors.text_primary ?? "#c0caf5"
                }
                MouseArea {
                    id: recMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("recorder")
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
