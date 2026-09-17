import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../"

Item {
    id: musicModule
    Layout.fillWidth: true
    Layout.fillHeight: true

    // ========================================================
    // MPRIS & PLAYER STATE PROPERTIES
    // ========================================================
    readonly property var activePlayer: {
        if (typeof Mpris === "undefined" || !Mpris.players) return null;
        var list = Mpris.players.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing) return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    property bool hasPlayer: activePlayer !== null || rawPlayerName !== ""
    property string playerName: activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "Media Player") : (rawPlayerName !== "" ? rawPlayerName : "Media Player")
    property bool isPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : rawIsPlaying
    property string songArtist: {
        if (activePlayer) {
            if (Array.isArray(activePlayer.trackArtists)) return activePlayer.trackArtists.join(", ");
            if (typeof activePlayer.trackArtists === "string") return activePlayer.trackArtists;
            if (typeof activePlayer.trackArtist === "string") return activePlayer.trackArtist;
        }
        return rawArtist;
    }
    property string songAlbum: rawAlbum
    property string albumArt: activePlayer ? (activePlayer.artUrl || "") : rawArtUrl

    property int currentPositionSec: 0
    property int totalLengthSec: 0
    property bool isDraggingSeek: false
    property int dragPositionSec: 0

    readonly property int displayPositionSec: isDraggingSeek ? dragPositionSec : currentPositionSec
    readonly property real seekRatio: totalLengthSec > 0 ? Math.max(0, Math.min(1.0, displayPositionSec / totalLengthSec)) : 0.0

    property real volumeLevel: 1.0
    property real previousVolume: 0.8
    property bool isShuffle: false
    property string loopMode: "None" // None, Track, Playlist

    // Raw fields from playerctl CLI fallback
    property string rawPlayerName: ""
    property bool rawIsPlaying: false
    property string rawTitle: ""
    property string rawArtist: ""
    property string rawAlbum: ""
    property string rawArtUrl: ""

    // ========================================================
    // FORMATTING HELPERS
    // ========================================================
    function formatTime(totalSec) {
        if (isNaN(totalSec) || totalSec <= 0) return "0:00";
        var hrs = Math.floor(totalSec / 3600);
        var mins = Math.floor((totalSec % 3600) / 60);
        var secs = Math.floor(totalSec % 60);
        if (hrs > 0) {
            return hrs + ":" + (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
        }
        return (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    // ========================================================
    // PLAYBACK CONTROLS
    // ========================================================
    function togglePlayPause() {
        musicModule.isPlaying = !musicModule.isPlaying;
        Quickshell.execDetached(["playerctl", "play-pause"]);
        syncTimer.restart();
    }

    function nextTrack() {
        Quickshell.execDetached(["playerctl", "next"]);
        syncTimer.restart();
    }

    function prevTrack() {
        Quickshell.execDetached(["playerctl", "previous"]);
        syncTimer.restart();
    }

    function toggleShuffle() {
        musicModule.isShuffle = !musicModule.isShuffle;
        Quickshell.execDetached(["playerctl", "shuffle", "toggle"]);
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
        Quickshell.execDetached(["playerctl", "volume", v.toFixed(2)]);
    }

    function toggleMute() {
        if (volumeLevel > 0.01) {
            previousVolume = volumeLevel;
            setVolume(0.0);
        } else {
            setVolume(previousVolume > 0.05 ? previousVolume : 0.8);
        }
    }

    function updateSeekFromMouse(mouseX, trackWidth) {
        if (trackWidth <= 0 || totalLengthSec <= 0) return;
        var ratio = Math.max(0.0, Math.min(1.0, mouseX / trackWidth));
        dragPositionSec = Math.round(ratio * totalLengthSec);
    }

    function commitSeekFromMouse(mouseX, trackWidth) {
        if (trackWidth <= 0 || totalLengthSec <= 0) return;
        var ratio = Math.max(0.0, Math.min(1.0, mouseX / trackWidth));
        var targetSec = Math.round(ratio * totalLengthSec);
        musicModule.currentPositionSec = targetSec;
        Quickshell.execDetached(["playerctl", "position", targetSec.toString()]);
        syncTimer.restart();
    }

    function seekRelative(deltaSec) {
        if (totalLengthSec <= 0) return;
        var targetSec = Math.max(0, Math.min(totalLengthSec, currentPositionSec + deltaSec));
        musicModule.currentPositionSec = targetSec;
        Quickshell.execDetached(["playerctl", "position", targetSec.toString()]);
        syncTimer.restart();
    }

    // ========================================================
    // BACKEND METADATA & POSITION SYNC
    // ========================================================
    Process {
        id: metadataSyncProcess
        running: false
        command: ["playerctl", "metadata", "--format", "{{playerName}}|||{{status}}|||{{title}}|||{{artist}}|||{{album}}|||{{mpris:artUrl}}|||{{position}}|||{{mpris:length}}|||{{volume}}|||{{loop}}|||{{shuffle}}"]
        stdout: StdioCollector {
            onStreamFinished: {
                var line = this.text.trim();
                if (line === "") {
                    musicModule.hasPlayer = (musicModule.activePlayer !== null);
                    return;
                }
                var parts = line.split("|||");
                if (parts.length >= 10) {
                    musicModule.hasPlayer = true;
                    musicModule.rawPlayerName = parts[0] || "Media Player";
                    musicModule.rawIsPlaying = (parts[1] === "Playing");
                    musicModule.rawTitle = parts[2] || "";
                    musicModule.rawArtist = parts[3] || "";
                    musicModule.rawAlbum = parts[4] || "";
                    musicModule.rawArtUrl = parts[5] || "";

                    var posMicros = parseInt(parts[6]);
                    if (!isNaN(posMicros) && !musicModule.isDraggingSeek) {
                        musicModule.currentPositionSec = Math.floor(posMicros / 1000000);
                    }

                    var lenMicros = parseInt(parts[7]);
                    if (!isNaN(lenMicros)) {
                        musicModule.totalLengthSec = Math.floor(lenMicros / 1000000);
                    }

                    var vol = parseFloat(parts[8]);
                    if (!isNaN(vol)) {
                        musicModule.volumeLevel = Math.max(0.0, Math.min(1.0, vol));
                    }

                    musicModule.loopMode = parts[9] || "None";
                    musicModule.isShuffle = (parts[10] === "true");
                }
            }
        }
    }

    // Periodic sync timer
    Timer {
        id: syncTimer
        interval: 1000
        repeat: true
        running: musicModule.visible
        onTriggered: {
            if (!metadataSyncProcess.running) {
                metadataSyncProcess.running = true;
            }
        }
    }

    // Local smooth position progression tick
    Timer {
        id: smoothPosTick
        interval: 1000
        repeat: true
        running: musicModule.visible && musicModule.isPlaying && !musicModule.isDraggingSeek
        onTriggered: {
            if (musicModule.totalLengthSec > 0 && musicModule.currentPositionSec < musicModule.totalLengthSec) {
                musicModule.currentPositionSec++;
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            metadataSyncProcess.running = true;
        }
    }

    Component.onCompleted: {
        metadataSyncProcess.running = true;
    }

    // ========================================================
    // UI LAYOUT
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 6

        // 1. TOP HEADER BAR
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 8

            // Back button
            Rectangle {
                width: 24; height: 24; radius: 8
                color: backMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: 1
                border.color: Theme.colors.border ?? "#16161e"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.colors.text_primary ?? "white"
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.previousExpandedMode === "utility") {
                            root.switchMode("utility", true);
                        } else {
                            root.collapseToIdle();
                        }
                    }
                }
            }

            // Player pill badge
            Rectangle {
                Layout.preferredHeight: 22
                implicitWidth: playerBadgeRow.implicitWidth + 16
                radius: 11
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                Row {
                    id: playerBadgeRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: {
                            var p = musicModule.playerName.toLowerCase();
                            if (p.includes("spotify")) return "󰓇";
                            if (p.includes("firefox") || p.includes("zen")) return "󰈹";
                            if (p.includes("chromium") || p.includes("chrome")) return "󰊯";
                            if (p.includes("mpv") || p.includes("vlc")) return "󰕼";
                            return "󰎆";
                        }
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: {
                            var p = musicModule.playerName.toLowerCase();
                            if (p.includes("spotify")) return "#1ed760";
                            if (p.includes("firefox") || p.includes("zen")) return "#ff7139";
                            return Theme.colors.accent ?? "#7aa2f7";
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: musicModule.playerName
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.colors.text_primary ?? "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Status Indicator Pill (Playing / Paused)
            Rectangle {
                Layout.preferredHeight: 20
                implicitWidth: statusRow.implicitWidth + 14
                radius: 10
                color: musicModule.isPlaying ? Qt.rgba(0.48, 0.64, 0.97, 0.12) : Qt.rgba(1, 1, 1, 0.05)

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: musicModule.isPlaying ? "#9ece6a" : "#565f89"
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            running: musicModule.isPlaying
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.3; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        text: musicModule.isPlaying ? "Playing" : "Paused"
                        font.pixelSize: 10
                        font.bold: true
                        color: musicModule.isPlaying ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // 2. MAIN TRACK & ART CARD ROW
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 74
            spacing: 12

            // Rounded Album Art Card
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                radius: 12
                color: "#1a1b26"
                clip: true
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)

                // Fallback Vinyl Record Disc when no artwork
                Item {
                    anchors.fill: parent
                    visible: artImage.status !== Image.Ready

                    Rectangle {
                        anchors.centerIn: parent
                        width: 60; height: 60; radius: 30
                        color: "#16161e"
                        border.width: 2; border.color: "#24283b"

                        Rectangle {
                            anchors.centerIn: parent
                            width: 40; height: 40; radius: 20
                            color: "transparent"
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: Theme.colors.accent ?? "#7aa2f7"

                            Text {
                                anchors.centerIn: parent
                                text: "󰝚"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: Theme.colors.bg ?? "#12141c"
                            }
                        }
                    }

                    RotationAnimation on rotation {
                        running: musicModule.isPlaying && artImage.status !== Image.Ready
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 6000
                    }
                }

                // Artwork Image
                Image {
                    id: artImage
                    anchors.fill: parent
                    source: musicModule.albumArt
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }

                // Hover Play/Pause Overlay on Artwork
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.45)
                    opacity: artMouse.containsMouse ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: musicModule.isPlaying ? "󰏤" : "󰐊"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: "white"
                    }
                }

                MouseArea {
                    id: artMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicModule.togglePlayPause()
                }
            }

            // Track Details & Equalizer Visualizer
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                // Title
                Text {
                    Layout.fillWidth: true
                    text: musicModule.songTitle || "No Track Playing"
                    font.pixelSize: 14
                    font.bold: true
                    color: Theme.colors.text_primary ?? "white"
                    elide: Text.ElideRight
                }

                // Artist / Album
                Text {
                    Layout.fillWidth: true
                    text: {
                        var artist = musicModule.songArtist !== "" ? musicModule.songArtist : "Unknown Artist";
                        if (musicModule.songAlbum !== "") return artist + " — " + musicModule.songAlbum;
                        return artist;
                    }
                    font.pixelSize: 12
                    color: Theme.colors.text_secondary ?? "#565f89"
                    elide: Text.ElideRight
                }

                // Apple-style Harmonic Live Audio Equalizer Bars
                Row {
                    id: eqRow
                    Layout.topMargin: 4
                    spacing: 2.5
                    opacity: musicModule.isPlaying ? 1.0 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 240 } }

                    readonly property var barHeights: [6, 14, 20, 11, 18, 22, 13, 19, 15, 21, 12, 17, 9, 16, 11, 7]
                    readonly property var barDurations: [320, 240, 380, 290, 420, 260, 350, 300, 270, 390, 250, 340, 410, 280, 330, 360]

                    Repeater {
                        model: 16
                        delegate: Rectangle {
                            width: 3
                            radius: 1.5
                            color: Theme.colors.accent ?? "#7aa2f7"
                            anchors.bottom: parent.bottom

                            property real targetA: eqRow.barHeights[index]
                            property real targetB: eqRow.barHeights[(index + 3) % 16]
                            height: musicModule.isPlaying ? targetA : 2

                            Behavior on height {
                                enabled: !musicModule.isPlaying
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }

                            SequentialAnimation on height {
                                running: musicModule.isPlaying
                                loops: Animation.Infinite
                                NumberAnimation { to: targetB; duration: eqRow.barDurations[index]; easing.type: Easing.InOutSine }
                                NumberAnimation { to: targetA; duration: eqRow.barDurations[(index + 1) % 16]; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }
        }

        // 3. SCRUBBABLE PROGRESS / SEEK BAR
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            spacing: 8

            // Elapsed Time
            Text {
                text: musicModule.formatTime(musicModule.displayPositionSec)
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                font.features: { "tnum": 1 }
                color: Theme.colors.text_secondary ?? "#565f89"
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
            }

            // Seek Bar Track with Thumb
            Item {
                id: seekTrackContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 16

                Rectangle {
                    id: seekBg
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 5
                    radius: 2.5
                    color: Qt.rgba(1, 1, 1, 0.12)

                    // Fill Bar
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0, Math.min(parent.width, parent.width * musicModule.seekRatio))
                        radius: 2.5
                        color: Theme.colors.accent ?? "#7aa2f7"
                    }
                }

                // Slider Thumb Handle
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width, (parent.width * musicModule.seekRatio) - (width / 2)))
                    width: (seekMouse.containsMouse || musicModule.isDraggingSeek) ? 12 : 9
                    height: width
                    radius: width / 2
                    color: "white"
                    border.width: 1
                    border.color: Theme.colors.accent ?? "#7aa2f7"
                    Behavior on width { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    id: seekMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onPressed: (mouse) => {
                        musicModule.isDraggingSeek = true;
                        musicModule.updateSeekFromMouse(mouse.x, width);
                    }
                    onPositionChanged: (mouse) => {
                        if (musicModule.isDraggingSeek) {
                            musicModule.updateSeekFromMouse(mouse.x, width);
                        }
                    }
                    onReleased: (mouse) => {
                        musicModule.commitSeekFromMouse(mouse.x, width);
                        musicModule.isDraggingSeek = false;
                    }
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        musicModule.seekRelative(wheel.angleDelta.y > 0 ? 5 : -5);
                    }
                }
            }

            // Total Duration
            Text {
                text: musicModule.totalLengthSec > 0 ? musicModule.formatTime(musicModule.totalLengthSec) : "--:--"
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                font.features: { "tnum": 1 }
                color: Theme.colors.text_secondary ?? "#565f89"
                Layout.preferredWidth: 36
            }
        }

        // 4. BOTTOM PLAYBACK & VOLUME CONTROLS
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 6

            // Left Playback Group
            Row {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                // Shuffle Button
                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: shuffMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰒟"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: musicModule.isShuffle ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 3; height: 3; radius: 1.5
                            color: Theme.colors.accent ?? "#7aa2f7"
                            visible: musicModule.isShuffle
                        }
                    }

                    MouseArea {
                        id: shuffMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.toggleShuffle()
                    }
                }

                // Previous Button
                Rectangle {
                    width: 32; height: 32; radius: 8
                    color: prevMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: Theme.colors.text_primary ?? "white"
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.prevTrack()
                    }
                }

                // Play / Pause Button (Hero Circle Button)
                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: Theme.colors.accent ?? "#7aa2f7"
                    scale: playMouse.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        // Small offset for play icon optical centering
                        anchors.horizontalCenterOffset: musicModule.isPlaying ? 0 : 1
                        text: musicModule.isPlaying ? "󰏤" : "󰐊"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        font.bold: true
                        color: Theme.colors.bg ?? "#12141c"
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.togglePlayPause()
                    }
                }

                // Next Button
                Rectangle {
                    width: 32; height: 32; radius: 8
                    color: nextMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: Theme.colors.text_primary ?? "white"
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.nextTrack()
                    }
                }

                // Loop Button
                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: loopMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: musicModule.loopMode === "Track" ? "󰑘" : "󰑖"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: musicModule.loopMode !== "None" ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 3; height: 3; radius: 1.5
                            color: Theme.colors.accent ?? "#7aa2f7"
                            visible: musicModule.loopMode !== "None"
                        }
                    }

                    MouseArea {
                        id: loopMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.cycleLoop()
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Right Volume Section
            Row {
                spacing: 5
                Layout.alignment: Qt.AlignVCenter

                // Volume Mute Button
                Rectangle {
                    width: 26; height: 26; radius: 6
                    color: volIconMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: musicModule.volumeLevel <= 0.01 ? "󰝟" :
                              (musicModule.volumeLevel < 0.4 ? "󰕿" :
                              (musicModule.volumeLevel < 0.7 ? "󰖀" : "󰕾"))
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: musicModule.volumeLevel <= 0.01 ? "#f7768e" : (Theme.colors.text_secondary ?? "#565f89")
                    }

                    MouseArea {
                        id: volIconMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.toggleMute()
                    }
                }

                // Interactive Volume Slider Bar
                Item {
                    width: 68
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5
                        radius: 2.5
                        color: Qt.rgba(1, 1, 1, 0.12)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(parent.width, parent.width * musicModule.volumeLevel))
                            radius: 2.5
                            color: musicModule.volumeLevel <= 0.01 ? "#f7768e" : (Theme.colors.accent ?? "#7aa2f7")
                        }
                    }

                    // Thumb
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, (parent.width * musicModule.volumeLevel) - (width / 2)))
                        width: volSliderMouse.containsMouse ? 10 : 7
                        height: width
                        radius: width / 2
                        color: "white"
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }

                    MouseArea {
                        id: volSliderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function applyVol(xPos) {
                            var ratio = Math.max(0.0, Math.min(1.0, xPos / width));
                            musicModule.setVolume(ratio);
                        }

                        onPressed: (mouse) => applyVol(mouse.x)
                        onPositionChanged: (mouse) => {
                            if (pressed) applyVol(mouse.x);
                        }
                        onWheel: (wheel) => {
                            wheel.accepted = true;
                            musicModule.setVolume(musicModule.volumeLevel + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
                        }
                    }
                }

                // Volume Percentage Label
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(musicModule.volumeLevel * 100) + "%"
                    font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                    font.features: { "tnum": 1 }
                    color: Theme.colors.text_secondary ?? "#565f89"
                    width: 28
                }
            }
        }
    }
}
