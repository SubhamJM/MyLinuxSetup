import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris
import "../"

Item {
    id: musicModule
    Layout.fillWidth: true
    Layout.fillHeight: true

    // ========================================================
    // 1. MPRIS & PLAYER STATE MANAGEMENT
    // ========================================================
    readonly property var availablePlayers: {
        if (typeof Mpris === "undefined" || !Mpris.players) return [];
        return Mpris.players.values || [];
    }

    property var manualActivePlayer: null
    readonly property var activePlayer: {
        if (manualActivePlayer && availablePlayers.indexOf(manualActivePlayer) !== -1) {
            return manualActivePlayer;
        }
        for (var i = 0; i < availablePlayers.length; i++) {
            if (availablePlayers[i].playbackState === MprisPlaybackState.Playing && (availablePlayers[i].trackTitle || availablePlayers[i].trackArtist)) {
                return availablePlayers[i];
            }
        }
        for (var j = 0; j < availablePlayers.length; j++) {
            if (availablePlayers[j].playbackState === MprisPlaybackState.Playing) {
                return availablePlayers[j];
            }
        }
        for (var k = 0; k < availablePlayers.length; k++) {
            if (availablePlayers[k].playbackState === MprisPlaybackState.Paused && (availablePlayers[k].trackTitle || availablePlayers[k].trackArtist)) {
                return availablePlayers[k];
            }
        }
        for (var m = 0; m < availablePlayers.length; m++) {
            if (availablePlayers[m].trackTitle || availablePlayers[m].trackArtist) {
                return availablePlayers[m];
            }
        }
        return availablePlayers.length > 0 ? availablePlayers[0] : null;
    }

    readonly property bool hasPlayer: activePlayer !== null || rawPlayerName !== ""
    readonly property bool isPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : rawIsPlaying
    readonly property string playerName: activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "Media Player") : (rawPlayerName || "Media Player")
    readonly property string songTitle: activePlayer ? (activePlayer.trackTitle || rawTitle || "") : rawTitle
    readonly property string songArtist: {
        if (activePlayer) {
            if (Array.isArray(activePlayer.trackArtists) && activePlayer.trackArtists.length > 0) return activePlayer.trackArtists.join(", ");
            if (typeof activePlayer.trackArtists === "string" && activePlayer.trackArtists !== "") return activePlayer.trackArtists;
            if (typeof activePlayer.trackArtist === "string" && activePlayer.trackArtist !== "") return activePlayer.trackArtist;
        }
        return rawArtist || "";
    }
    readonly property string songAlbum: {
        if (activePlayer && activePlayer.trackAlbum) return activePlayer.trackAlbum;
        return rawAlbum || "";
    }
    readonly property string albumArt: {
        if (rawArtUrl && (rawArtUrl.startsWith("file://") || rawArtUrl.startsWith("/"))) return rawArtUrl;
        if (typeof dashMod !== "undefined" && dashMod.currentAlbumArt && dashMod.currentAlbumArt !== "") return dashMod.currentAlbumArt;
        if (activePlayer && activePlayer.trackArtUrl && activePlayer.trackArtUrl.startsWith("file://")) return activePlayer.trackArtUrl;
        return rawArtUrl || "";
    }

    // Positions & Duration
    property int currentPositionSec: 0
    property int totalLengthSec: 0
    property bool isDraggingSeek: false
    property int dragPositionSec: 0
    readonly property int displayPositionSec: isDraggingSeek ? dragPositionSec : currentPositionSec
    readonly property real seekRatio: totalLengthSec > 0 ? Math.max(0.0, Math.min(1.0, displayPositionSec / totalLengthSec)) : 0.0

    // Volume, Loop & Shuffle
    property real volumeLevel: 1.0
    property real previousVolume: 0.8
    property bool isShuffle: activePlayer ? (activePlayer.shuffle ?? false) : rawShuffle
    property string loopMode: "None" // None, Track, Playlist

    // Active Drawer Panel ("volume", "devices", "players", or "")
    property string activePanel: ""
    function togglePanel(panelName) {
        activePanel = (activePanel === panelName) ? "" : panelName;
    }

    // Dynamic Height calculation (DMS style)
    readonly property real baseCardHeight: 335
    readonly property real calculatedHeight: {
        if (!hasPlayer && !rawIsPlaying) return 240;
        if (activePanel === "volume") return baseCardHeight + 64;
        if (activePanel === "devices") return baseCardHeight + Math.max(1, Math.min(4, sinksModel.count)) * 46 + 18;
        if (activePanel === "players") return baseCardHeight + Math.max(1, Math.min(4, availablePlayers.length)) * 46 + 18;
        return baseCardHeight;
    }

    // Dynamic Accent Color (with ColorQuantizer extraction or Theme fallback)
    property color accentColor: Theme.colors.accent ?? "#7aa2f7"
    ColorQuantizer {
        id: quantizer
        source: musicModule.albumArt
        depth: 4
        rescaleSize: 64
        onColorsChanged: {
            if (colors && colors.length > 0) {
                var c = colors[0];
                var lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
                if (lum > 0.15 && lum < 0.90) {
                    musicModule.accentColor = c;
                } else {
                    musicModule.accentColor = Theme.colors.accent ?? "#7aa2f7";
                }
            }
        }
    }

    readonly property color onAccentColor: {
        var lum = 0.2126 * accentColor.r + 0.7152 * accentColor.g + 0.0722 * accentColor.b;
        return lum > 0.6 ? "#16161e" : "#ffffff";
    }

    // ========================================================
    // CAVA AUDIO VISUALIZER & ENERGY PROCESS (DMS style)
    // ========================================================
    CavaProcess {
        id: musicCava
        active: musicModule.visible && musicModule.isPlaying
        bars: 16
    }

    Timer {
        id: vizTimer
        property int tick: 0
        interval: 40
        repeat: true
        running: musicModule.visible && musicModule.isPlaying
        onTriggered: tick = (tick + 1) % 10000
    }

    readonly property real auraEnergy: {
        if (!musicModule.isPlaying) return 0.0;
        if (musicCava.audioSignalActive && musicCava.points.length >= 2) {
            var bass = (musicCava.points[0] + musicCava.points[1]) / (2 * Math.max(1, musicCava.normalizationCeiling));
            return Math.min(1.0, Math.max(0.0, bass));
        }
        return 0.35 + 0.35 * Math.abs(Math.sin(vizTimer.tick * 0.12));
    }

    // Fallback CLI fields
    property string rawPlayerName: ""
    property bool rawIsPlaying: false
    property string rawTitle: ""
    property string rawArtist: ""
    property string rawAlbum: ""
    property string rawArtUrl: ""
    property bool rawShuffle: false

    // ========================================================
    // 2. CONTROLS & LOGIC
    // ========================================================
    function formatTime(totalSec) {
        if (isNaN(totalSec) || totalSec <= 0) return "0:00";
        var m = Math.floor(totalSec / 60);
        var s = Math.floor(totalSec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function togglePlayPause() {
        if (activePlayer && activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying();
        } else {
            Quickshell.execDetached(["playerctl", "play-pause"]);
        }
        syncTimer.restart();
    }

    function nextTrack() {
        if (activePlayer && activePlayer.canGoNext) {
            activePlayer.next();
        } else {
            Quickshell.execDetached(["playerctl", "next"]);
        }
        syncTimer.restart();
    }

    function prevTrack() {
        if (activePlayer && activePlayer.canGoPrevious) {
            activePlayer.previous();
        } else {
            Quickshell.execDetached(["playerctl", "previous"]);
        }
        syncTimer.restart();
    }

    function toggleShuffle() {
        if (activePlayer && activePlayer.shuffleSupported) {
            activePlayer.shuffle = !activePlayer.shuffle;
        } else {
            Quickshell.execDetached(["playerctl", "shuffle", "toggle"]);
        }
        syncTimer.restart();
    }

    function cycleLoop() {
        var nextLoop = "None";
        if (loopMode === "None") nextLoop = "Track";
        else if (loopMode === "Track") nextLoop = "Playlist";
        else nextLoop = "None";
        musicModule.loopMode = nextLoop;
        Quickshell.execDetached(["playerctl", "loop", nextLoop]);
        syncTimer.restart();
    }

    function setVolume(val) {
        var v = Math.max(0.0, Math.min(1.0, val));
        musicModule.volumeLevel = v;
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)]);
        Quickshell.execDetached(["playerctl", "volume", v.toFixed(2)]);
    }

    function adjustVolume(step) {
        setVolume(volumeLevel + step);
    }

    function toggleMute() {
        if (volumeLevel > 0.01) {
            previousVolume = volumeLevel;
            setVolume(0.0);
        } else {
            setVolume(previousVolume > 0.05 ? previousVolume : 0.6);
        }
    }

    function seekRelative(deltaSec) {
        if (totalLengthSec <= 0) return;
        var targetSec = Math.max(0, Math.min(totalLengthSec, currentPositionSec + deltaSec));
        musicModule.currentPositionSec = targetSec;
        Quickshell.execDetached(["playerctl", "position", targetSec.toString()]);
    }

    function commitSeekRatio(ratio) {
        if (totalLengthSec <= 0) return;
        var targetSec = Math.round(ratio * totalLengthSec);
        musicModule.currentPositionSec = targetSec;
        Quickshell.execDetached(["playerctl", "position", targetSec.toString()]);
    }

    function getAudioDeviceIcon(name, desc) {
        var n = ((name || "") + " " + (desc || "")).toLowerCase();
        if (n.includes("bluez") || n.includes("buds") || n.includes("headset") || n.includes("headphone") || n.includes("ear")) return "headset";
        if (n.includes("hdmi") || n.includes("displayport") || n.includes("tv")) return "tv";
        return "speaker";
    }

    // Audio Sinks model via audio_devices.py
    ListModel {
        id: sinksModel
    }

    Process {
        id: sinksPoller
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    if (data && Array.isArray(data.sinks)) {
                        sinksModel.clear();
                        for (var i = 0; i < data.sinks.length; i++) {
                            sinksModel.append({
                                devId: data.sinks[i].id || "",
                                name: data.sinks[i].name || "",
                                desc: data.sinks[i].desc || "Audio Sink",
                                isDefault: !!data.sinks[i].isDefault
                            });
                        }
                    }
                } catch(e) {}
            }
        }
    }

    // CLI metadata sync fallback via mpris-status.py
    Process {
        id: metadataSyncProcess
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/mpris-status.py").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                if (lines.length >= 4) {
                    var status = lines[0] ? lines[0].trim() : "";
                    musicModule.rawIsPlaying = (status === "Playing");
                    musicModule.rawTitle = lines[1] ? lines[1].trim() : "";
                    musicModule.rawArtist = lines[2] ? lines[2].trim() : "";
                    var art = lines[3] ? lines[3].trim() : "";
                    if (art !== "") musicModule.rawArtUrl = art;

                    var posMicros = parseInt(lines[4]);
                    if (!isNaN(posMicros) && !musicModule.isDraggingSeek) {
                        musicModule.currentPositionSec = Math.floor(posMicros / 1000000);
                    }

                    var lenMicros = parseInt(lines[5]);
                    if (!isNaN(lenMicros)) {
                        musicModule.totalLengthSec = Math.floor(lenMicros / 1000000);
                    }
                }
            }
        }
    }

    Timer {
        id: syncTimer
        interval: 1000
        repeat: true
        running: musicModule.visible
        onTriggered: {
            if (!metadataSyncProcess.running) metadataSyncProcess.running = true;
            if (activePanel === "devices" && !sinksPoller.running) sinksPoller.running = true;
        }
    }

    Timer {
        id: localSecondTick
        interval: 1000
        repeat: true
        running: musicModule.visible && musicModule.isPlaying && !musicModule.isDraggingSeek
        onTriggered: {
            if (musicModule.totalLengthSec > 0 && musicModule.currentPositionSec < musicModule.totalLengthSec) {
                musicModule.currentPositionSec++;
            }
        }
    }

    Component.onCompleted: {
        metadataSyncProcess.running = true;
        sinksPoller.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            metadataSyncProcess.running = true;
            sinksPoller.running = true;
            forceActiveFocus();
        } else {
            activePanel = "";
        }
    }

    // Keyboard Shortcuts
    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.collapseToIdle();
            event.accepted = true;
        } else if (event.key === Qt.Key_Space) {
            togglePlayPause();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            seekRelative(-5);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            seekRelative(5);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            adjustVolume(0.05);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            adjustVolume(-0.05);
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            toggleMute();
            event.accepted = true;
        }
    }

    // ========================================================
    // 3. MEDIA ARTWORK BLUR BACKDROP (DMS MediaArtBackdrop)
    // ========================================================
    Item {
        id: backdropContainer
        anchors.fill: parent
        clip: true

        Image {
            id: backdropImg
            anchors.fill: parent
            source: musicModule.albumArt
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
            cache: true
        }

        MultiEffect {
            anchors.fill: parent
            source: backdropImg
            blurEnabled: true
            blurMax: 64
            blur: 0.85
            saturation: -0.15
            brightness: -0.28
            opacity: musicModule.albumArt !== "" ? 0.75 : 0.0
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
        }

        // Dark acrylic overlay tint
        Rectangle {
            anchors.fill: parent
            color: Theme.colors.bg ?? "#16161e"
            opacity: musicModule.albumArt !== "" ? 0.78 : 0.95
        }
    }

    // ========================================================
    // 4. EMPTY STATE ("No Active Players")
    // ========================================================
    Column {
        anchors.centerIn: parent
        spacing: 14
        visible: !musicModule.hasPlayer && !musicModule.rawIsPlaying

        MaterialSymbol {
            text: "music_note"
            iconSize: 52
            color: Theme.colors.text_muted ?? "#565f89"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "No Active Players"
            font.family: "Rubik"
            font.pixelSize: 18
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Play media in Spotify, YouTube, or your browser"
            font.family: "Noto Sans"
            font.pixelSize: 12
            color: Theme.colors.text_muted ?? "#565f89"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ========================================================
    // 5. DMS MAIN CARD BODY (1:1 Carbon Copy of MediaPlayerIslandChrome)
    // ========================================================
    Item {
        id: cardBody
        anchors.fill: parent
        anchors.margins: 18
        visible: musicModule.hasPlayer || musicModule.rawIsPlaying

        // ----------------------------------------------------
        // TOP HEADER: Artwork + Info + Pill Button Cluster
        // ----------------------------------------------------
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 150

            // 0. REACTIVE AUDIO AURA / HALO (DMS MediaBlobHalo style)
            Rectangle {
                id: artAura
                anchors.centerIn: artBox
                width: artBox.width + (musicModule.isPlaying ? (10 + musicModule.auraEnergy * 14) : 0)
                height: artBox.height + (musicModule.isPlaying ? (10 + musicModule.auraEnergy * 14) : 0)
                radius: artBox.radius + 6
                color: Qt.rgba(musicModule.accentColor.r, musicModule.accentColor.g, musicModule.accentColor.b, musicModule.isPlaying ? 0.22 : 0.0)
                border.width: 1.5
                border.color: Qt.rgba(musicModule.accentColor.r, musicModule.accentColor.g, musicModule.accentColor.b, musicModule.isPlaying ? (0.4 + musicModule.auraEnergy * 0.4) : 0.0)
                opacity: musicModule.isPlaying ? 0.95 : 0.0
                z: 0
                Behavior on opacity { NumberAnimation { duration: 250 } }
                Behavior on width { NumberAnimation { duration: 75; easing.type: Easing.OutQuad } }
                Behavior on height { NumberAnimation { duration: 75; easing.type: Easing.OutQuad } }
            }

            // 1. ALBUM ARTWORK (150x150, cornerRadius 26)
            Rectangle {
                id: artBox
                z: 1
                width: 150
                height: 150
                radius: 26
                color: Qt.rgba(1, 1, 1, 0.08)
                clip: true

                // Subtle ambient drop shadow inside card
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.12)
                    z: 2
                }

                // Fallback icon
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: 56
                    color: musicModule.accentColor
                    visible: artImage.status !== Image.Ready
                }

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: musicModule.albumArt
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                }
            }

            // 2. TOP-RIGHT PILL BUTTON CLUSTER (Volume, Output Devices, Players)
            Row {
                id: buttonGroup
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 6

                // Volume Button
                Rectangle {
                    id: volumeBtn
                    width: 42; height: 42
                    radius: 21
                    color: (musicModule.activePanel === "volume") ? Qt.rgba(musicModule.accentColor.r, musicModule.accentColor.g, musicModule.accentColor.b, 0.24) : 
                           (volArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                    border.width: 1
                    border.color: (musicModule.activePanel === "volume") ? musicModule.accentColor : Qt.rgba(255, 255, 255, 0.1)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: musicModule.volumeLevel <= 0.01 ? "volume_off" : (musicModule.volumeLevel < 0.5 ? "volume_down" : "volume_up")
                        iconSize: 20
                        color: (musicModule.activePanel === "volume") ? musicModule.accentColor : (Theme.colors.text_primary ?? "white")
                    }

                    MouseArea {
                        id: volArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.togglePanel("volume")
                        onWheel: function(wheel) {
                            wheel.accepted = true;
                            musicModule.adjustVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                        }
                    }
                }

                // Audio Devices Button
                Rectangle {
                    id: outputBtn
                    width: 42; height: 42
                    radius: 21
                    color: (musicModule.activePanel === "devices") ? Qt.rgba(musicModule.accentColor.r, musicModule.accentColor.g, musicModule.accentColor.b, 0.24) : 
                           (outputArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                    border.width: 1
                    border.color: (musicModule.activePanel === "devices") ? musicModule.accentColor : Qt.rgba(255, 255, 255, 0.1)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: {
                            for (var i = 0; i < sinksModel.count; i++) {
                                if (sinksModel.get(i).isDefault) {
                                    return musicModule.getAudioDeviceIcon(sinksModel.get(i).name, sinksModel.get(i).desc);
                                }
                            }
                            return "speaker";
                        }
                        iconSize: 20
                        color: (musicModule.activePanel === "devices") ? musicModule.accentColor : (Theme.colors.text_primary ?? "white")
                    }

                    MouseArea {
                        id: outputArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sinksPoller.running = true;
                            musicModule.togglePanel("devices");
                        }
                        onWheel: function(wheel) {
                            wheel.accepted = true;
                            if (sinksModel.count > 1) {
                                var currIdx = 0;
                                for (var i = 0; i < sinksModel.count; i++) {
                                    if (sinksModel.get(i).isDefault) { currIdx = i; break; }
                                }
                                var nextIdx = (currIdx + (wheel.angleDelta.y > 0 ? 1 : -1) + sinksModel.count) % sinksModel.count;
                                var target = sinksModel.get(nextIdx);
                                if (target) {
                                    Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", ""), "set-sink", target.name]);
                                    sinksPoller.running = true;
                                }
                            }
                        }
                    }
                }

                // Players / Source Button
                Rectangle {
                    id: sourceBtn
                    width: 42; height: 42
                    radius: 21
                    visible: musicModule.availablePlayers.length > 0
                    color: (musicModule.activePanel === "players") ? Qt.rgba(musicModule.accentColor.r, musicModule.accentColor.g, musicModule.accentColor.b, 0.24) : 
                           (sourceArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                    border.width: 1
                    border.color: (musicModule.activePanel === "players") ? musicModule.accentColor : Qt.rgba(255, 255, 255, 0.1)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "assistant_device"
                        iconSize: 20
                        color: (musicModule.activePanel === "players") ? musicModule.accentColor : (Theme.colors.text_primary ?? "white")
                    }

                    MouseArea {
                        id: sourceArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.togglePanel("players")
                    }
                }
            }

            // 3. TRACK METADATA & SPECTRUM VISUALIZER
            Column {
                anchors.left: artBox.right
                anchors.leftMargin: 16
                anchors.right: buttonGroup.left
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 2
                spacing: 4

                // Player Identity & Playing Badge
                Row {
                    spacing: 6
                    width: parent.width

                    MaterialSymbol {
                        text: "equalizer"
                        iconSize: 13
                        color: musicModule.accentColor
                        anchors.verticalCenter: parent.verticalCenter
                        visible: musicModule.isPlaying
                    }

                    Text {
                        text: (musicModule.playerName || "Media Player").toUpperCase()
                        font.family: "Rubik"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.1
                        color: musicModule.accentColor
                        opacity: 0.9
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    text: musicModule.songTitle || "Unknown Title"
                    font.family: "Rubik"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: Theme.colors.text_primary ?? "#ffffff"
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    lineHeight: 1.15
                }

                Text {
                    width: parent.width
                    text: musicModule.songArtist || "Unknown Artist"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: musicModule.accentColor
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    text: musicModule.songAlbum
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    color: Theme.colors.text_secondary ?? "#565f89"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }

                // Dynamic Audio Spectrum Visualizer (DMS AudioVisualization style)
                Item {
                    id: specVizContainer
                    width: parent.width
                    height: 22
                    visible: musicModule.isPlaying

                    Row {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        spacing: 3

                        Repeater {
                            model: 16
                            Rectangle {
                                width: 4
                                radius: 2
                                anchors.bottom: parent.bottom
                                color: musicModule.accentColor
                                opacity: 0.88
                                height: {
                                    if (!musicModule.isPlaying) return 3;
                                    if (musicCava.audioSignalActive && musicCava.points.length > index) {
                                        var lvl = Math.min(1.0, (musicCava.points[index] || 0) / Math.max(1, musicCava.normalizationCeiling));
                                        return Math.max(3, lvl * 20);
                                    }
                                    // Smooth rhythmic wave fallback so visualizer is alive during playback
                                    var wave = 0.25 + 0.65 * Math.abs(Math.sin((vizTimer.tick * 0.16) + index * 0.42));
                                    return Math.max(3, wave * 18);
                                }
                                Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                            }
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------
        // MIDDLE: SEEKBAR & TIMESTAMPS (DankSeekbar)
        // ----------------------------------------------------
        Item {
            id: seekBlock
            anchors.top: header.bottom
            anchors.topMargin: 18
            anchors.left: parent.left
            anchors.right: parent.right
            height: 38

            // Progress Bar Track
            Rectangle {
                id: seekTrack
                anchors.top: parent.top
                anchors.topMargin: 6
                width: parent.width
                height: 5
                radius: 2.5
                color: Qt.rgba(1, 1, 1, 0.14)

                // Fill Bar
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * musicModule.seekRatio
                    radius: parent.radius
                    color: musicModule.accentColor
                    Behavior on width {
                        enabled: !musicModule.isDraggingSeek
                        NumberAnimation { duration: 120 }
                    }
                }

                // Playhead Handle
                Rectangle {
                    width: 12; height: 12
                    radius: 6
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width, (parent.width * musicModule.seekRatio) - (width / 2)))
                    color: "#ffffff"
                    border.width: 2
                    border.color: musicModule.accentColor
                    visible: seekMouse.containsMouse || musicModule.isDraggingSeek
                    scale: musicModule.isDraggingSeek ? 1.25 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    id: seekMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(mouse) {
                        musicModule.isDraggingSeek = true;
                        var ratio = Math.max(0.0, Math.min(1.0, (mouse.x - 8) / (seekTrack.width)));
                        musicModule.dragPositionSec = Math.round(ratio * musicModule.totalLengthSec);
                    }
                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            var ratio = Math.max(0.0, Math.min(1.0, (mouse.x - 8) / (seekTrack.width)));
                            musicModule.dragPositionSec = Math.round(ratio * musicModule.totalLengthSec);
                        }
                    }
                    onReleased: function(mouse) {
                        if (musicModule.isDraggingSeek) {
                            var ratio = Math.max(0.0, Math.min(1.0, (mouse.x - 8) / (seekTrack.width)));
                            musicModule.commitSeekRatio(ratio);
                            musicModule.isDraggingSeek = false;
                        }
                    }
                }
            }

            // Time Labels
            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: musicModule.formatTime(musicModule.displayPositionSec)
                color: musicModule.accentColor
                font.family: "Rubik"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: musicModule.totalLengthSec > 0 ? musicModule.formatTime(musicModule.totalLengthSec) : "--:--"
                color: Theme.colors.text_secondary ?? "#565f89"
                font.family: "Rubik"
                font.pixelSize: 12
            }
        }

        // ----------------------------------------------------
        // BOTTOM: TRANSPORT PLAYBACK CONTROLS (DMS Layout)
        // ----------------------------------------------------
        Row {
            id: transportRow
            anchors.top: seekBlock.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            height: 56
            spacing: 14

            // 1. Shuffle Button
            Rectangle {
                width: 48; height: 48
                radius: 24
                anchors.verticalCenter: parent.verticalCenter
                color: musicModule.isShuffle ? Qt.rgba(musicModule.accentColor.r, musicModule.accentColor.g, musicModule.accentColor.b, 0.25) :
                       (shuffleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "shuffle"
                    iconSize: 22
                    color: musicModule.isShuffle ? musicModule.accentColor : (Theme.colors.text_secondary ?? "#8e8e93")
                }

                MouseArea {
                    id: shuffleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicModule.toggleShuffle()
                }
            }

            // 2. Skip Previous Button
            Rectangle {
                width: 64; height: 54
                radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                scale: prevMouse.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "skip_previous"
                    iconSize: 26
                    color: Theme.colors.text_primary ?? "#ffffff"
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicModule.prevTrack()
                }
            }

            // 3. Central Play / Pause Button (96x54 rounded pill in accentColor)
            Rectangle {
                width: 96; height: 54
                radius: 27
                anchors.verticalCenter: parent.verticalCenter
                color: musicModule.accentColor
                scale: playMouse.pressed ? 0.93 : (playMouse.containsMouse ? 1.03 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                // Elevation glow / shadow effect
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.3)
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: musicModule.isPlaying ? "pause" : "play_arrow"
                    iconSize: 32
                    color: musicModule.onAccentColor
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicModule.togglePlayPause()
                }
            }

            // 4. Skip Next Button
            Rectangle {
                width: 64; height: 54
                radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                scale: nextMouse.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "skip_next"
                    iconSize: 26
                    color: Theme.colors.text_primary ?? "#ffffff"
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicModule.nextTrack()
                }
            }

            // 5. Repeat / Loop Button
            Rectangle {
                width: 48; height: 48
                radius: 24
                anchors.verticalCenter: parent.verticalCenter
                color: (musicModule.loopMode !== "None") ? Qt.rgba(musicModule.accentColor.r, musicModule.accentColor.g, musicModule.accentColor.b, 0.25) :
                       (repeatMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: musicModule.loopMode === "Track" ? "repeat_one" : "repeat"
                    iconSize: 22
                    color: (musicModule.loopMode !== "None") ? musicModule.accentColor : (Theme.colors.text_secondary ?? "#8e8e93")
                }

                MouseArea {
                    id: repeatMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicModule.cycleLoop()
                }
            }
        }

        // ----------------------------------------------------
        // EXPANDABLE DRAWER PANELS (Volume / Devices / Players)
        // ----------------------------------------------------
        Rectangle {
            id: panelBox
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: transportRow.bottom
            anchors.topMargin: 12
            height: {
                if (musicModule.activePanel === "volume") return 54;
                if (musicModule.activePanel === "devices") return Math.max(1, Math.min(4, sinksModel.count)) * 46 + 12;
                if (musicModule.activePanel === "players") return Math.max(1, Math.min(4, musicModule.availablePlayers.length)) * 46 + 12;
                return 0;
            }
            radius: 18
            color: Qt.rgba(0, 0, 0, 0.35)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.08)
            visible: musicModule.activePanel !== ""
            clip: true
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

            // 1. VOLUME PANEL
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12
                visible: musicModule.activePanel === "volume"

                Rectangle {
                    width: 38; height: 38; radius: 19
                    color: muteBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: musicModule.volumeLevel <= 0.01 ? "volume_off" : "volume_up"
                        iconSize: 20
                        color: musicModule.volumeLevel <= 0.01 ? "#f7768e" : musicModule.accentColor
                    }
                    MouseArea {
                        id: muteBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.toggleMute()
                    }
                }

                // Volume Slider
                Rectangle {
                    id: volSliderTrack
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.14)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * musicModule.volumeLevel
                        radius: parent.radius
                        color: musicModule.accentColor
                    }

                    Rectangle {
                        width: 16; height: 16; radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, (parent.width * musicModule.volumeLevel) - (width / 2)))
                        color: "#ffffff"
                        border.width: 2
                        border.color: musicModule.accentColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                var ratio = Math.max(0.0, Math.min(1.0, (mouse.x - 10) / volSliderTrack.width));
                                musicModule.setVolume(ratio);
                            }
                        }
                        onPressed: function(mouse) {
                            var ratio = Math.max(0.0, Math.min(1.0, (mouse.x - 10) / volSliderTrack.width));
                            musicModule.setVolume(ratio);
                        }
                    }
                }

                Text {
                    text: Math.round(musicModule.volumeLevel * 100) + "%"
                    font.family: "Rubik"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.colors.text_primary ?? "#ffffff"
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                }
            }

            // 2. AUDIO DEVICES PANEL
            ListView {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4
                clip: true
                visible: musicModule.activePanel === "devices"
                model: sinksModel
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 42
                    radius: 12
                    color: model.isDefault ? Qt.rgba(musicModule.accentColor.r, musicModule.accentColor.g, musicModule.accentColor.b, 0.22) :
                           (devItemArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                    border.width: model.isDefault ? 1 : 0
                    border.color: musicModule.accentColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        MaterialSymbol {
                            text: musicModule.getAudioDeviceIcon(model.name, model.desc)
                            iconSize: 20
                            color: model.isDefault ? musicModule.accentColor : (Theme.colors.text_primary ?? "white")
                        }

                        Text {
                            text: model.desc
                            font.family: "Noto Sans"
                            font.pixelSize: 13
                            font.weight: model.isDefault ? Font.Bold : Font.Normal
                            color: model.isDefault ? (Theme.colors.text_primary ?? "white") : (Theme.colors.text_secondary ?? "#aeaeb2")
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: musicModule.accentColor
                            visible: model.isDefault
                        }
                    }

                    MouseArea {
                        id: devItemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", ""), "set-sink", model.name]);
                            sinksPoller.running = true;
                        }
                    }
                }
            }

            // 3. PLAYERS PANEL
            ListView {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4
                clip: true
                visible: musicModule.activePanel === "players"
                model: musicModule.availablePlayers
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 42
                    radius: 12
                    property bool isCur: modelData === musicModule.activePlayer
                    color: isCur ? Qt.rgba(musicModule.accentColor.r, musicModule.accentColor.g, musicModule.accentColor.b, 0.22) :
                           (playerItemArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                    border.width: isCur ? 1 : 0
                    border.color: musicModule.accentColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        MaterialSymbol {
                            text: "music_note"
                            iconSize: 20
                            color: isCur ? musicModule.accentColor : (Theme.colors.text_primary ?? "white")
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: modelData?.identity || modelData?.desktopEntry || "Player"
                                font.family: "Rubik"
                                font.pixelSize: 13
                                font.weight: isCur ? Font.Bold : Font.Normal
                                color: isCur ? (Theme.colors.text_primary ?? "white") : (Theme.colors.text_primary ?? "#e0e0e0")
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData?.trackTitle || "Idle"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                color: Theme.colors.text_muted ?? "#8e8e93"
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: musicModule.accentColor
                            visible: isCur
                        }
                    }

                    MouseArea {
                        id: playerItemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            musicModule.manualActivePlayer = modelData;
                        }
                    }
                }
            }
        }
    }
}
