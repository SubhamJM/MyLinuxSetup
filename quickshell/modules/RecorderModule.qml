import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: recModule
    spacing: 10
    Layout.fillWidth: true
    Layout.fillHeight: true

    // ========================================================
    // 1. MATERIAL DESIGN 3 / MATERIAL YOU DESIGN TOKENS
    // ========================================================
    readonly property color colSurface: Theme.colors.bg ?? "#16161e"
    readonly property color colCard: Theme.colors.card_bg ?? "#1f2335"
    readonly property color colCardHover: Theme.colors.hover_bg ?? "#24283b"
    readonly property color colAccent: Theme.colors.accent ?? "#7aa2f7"
    readonly property color colAccentContainer: Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.16)
    readonly property color colTextPrimary: Theme.colors.text_primary ?? "#c0caf5"
    readonly property color colTextSecondary: Theme.colors.text_secondary ?? "#9da9a0"
    readonly property color colTextMuted: Theme.colors.text_muted ?? "#565f89"
    readonly property color colBorder: Theme.colors.border ?? Qt.rgba(1, 1, 1, 0.08)
    readonly property color colBorderHover: Theme.colors.border_hover ?? colAccent
    readonly property color colRed: ({ nord: "#bf616a", dracula: "#ff5555", catppuccin: "#f38ba8", everforest: "#e67e80", "rose-pine": "#eb6f92" })[Theme.currentThemeName] ?? "#ff5555"
    readonly property color colRedContainer: Qt.rgba(colRed.r, colRed.g, colRed.b, 0.20)

    // ========================================================
    // 2. RECORDER STATE & PROCESSES
    // ========================================================
    property string saveDirectory: "~/Videos"
    property bool recordAudio: false
    property string selectedSourceId: ""
    property string selectedSourceName: "Default System Mic"
    property bool isMicDropdownOpen: false
    property bool isRecording: false
    property int recordSeconds: 0
    property string freeDiskSpace: "114G Free"

    ListModel { id: micSourcesModel }

    // Audio Input Scanner (pactl / pipewire)
    Process {
        id: micScanner
        running: root.activeMode === "recorder" || (root.activeMode === "utility" && typeof utilMod !== "undefined" && utilMod.activeSection === "recorder")
        command: ["sh", "-c", `
            python3 -c "
import subprocess

try:
    output = subprocess.check_output(['pactl', 'list', 'sources'], text=True)
    sources = []
    current_name = None
    current_desc = None

    for line in output.splitlines():
        line = line.strip()
        if line.startswith('Name:'):
            current_name = line.split('Name:', 1)[1].strip()
        elif line.startswith('Description:'):
            current_desc = line.split('Description:', 1)[1].strip()
        
        if current_name and current_desc:
            if not current_name.endswith('.monitor'):
                sources.append(f'{current_name}|||{current_desc}')
            current_name = None
            current_desc = None

    print('\n'.join(sources))
except Exception:
    pass
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                micSourcesModel.clear();
                micSourcesModel.append({
                    "sourceId": "@DEFAULT_SOURCE@",
                    "sourceName": "Default System Mic"
                });

                var lines = this.text.trim().split("\n");
                var defaultChosen = (recModule.selectedSourceId !== "");

                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 2) {
                        micSourcesModel.append({
                            "sourceId": parts[0].trim(),
                            "sourceName": parts[1].trim()
                        });
                        if (!defaultChosen && i === 0) {
                            recModule.selectedSourceId = parts[0].trim();
                            recModule.selectedSourceName = parts[1].trim();
                        }
                    }
                }

                if (recModule.selectedSourceId === "") {
                    recModule.selectedSourceId = "@DEFAULT_SOURCE@";
                    recModule.selectedSourceName = "Default System Mic";
                }
            }
        }
    }

    // Disk space checker
    Process {
        id: diskChecker
        running: root.activeMode === "recorder"
        command: ["sh", "-c", "df -h ~/Videos 2>/dev/null | awk 'NR==2{print $4}' || df -h ~ | awk 'NR==2{print $4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = this.text.trim();
                if (val) recModule.freeDiskSpace = val + " Free";
            }
        }
    }

    // Process checker: synchronizes with kernel elapsed time if wf-recorder is running
    Process {
        id: statusChecker
        running: true
        command: ["sh", "-c", "pgrep -x wf-recorder > /dev/null && echo 'running:'$(ps -o etimes= -C wf-recorder 2>/dev/null | head -n 1 | tr -d ' ') || echo 'stopped'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim();
                if (out.startsWith("running")) {
                    recModule.isRecording = true;
                    root.isScreenRecording = true;
                    var parts = out.split(":");
                    if (parts.length >= 2 && parts[1]) {
                        var parsedSec = parseInt(parts[1]);
                        if (!isNaN(parsedSec) && parsedSec >= 0) {
                            recModule.recordSeconds = parsedSec;
                        }
                    }
                } else {
                    recModule.isRecording = false;
                    root.isScreenRecording = false;
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (recModule.isRecording) {
                recModule.recordSeconds++;
            }
            if (!statusChecker.running) statusChecker.running = true;
            if (root.activeMode === "recorder" && !diskChecker.running) diskChecker.running = true;
        }
    }

    function formatTime(totalSec) {
        var s = totalSec || 0;
        var mins = Math.floor(s / 60);
        var secs = s % 60;
        return (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    function startRecording(regionMode) {
        var expandedDir = saveDirectory.replace(/^~/, Quickshell.env("HOME"));
        var filename = "recording_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + ".mp4";
        
        var audioCmd = "";
        if (recModule.recordAudio) {
            var targetSrc = recModule.selectedSourceId !== "" ? recModule.selectedSourceId : "@DEFAULT_SOURCE@";
            audioCmd = "--audio=" + targetSrc;
        }
        
        var recordCmd = "";
        if (regionMode) {
            recordCmd = `mkdir -p "${expandedDir}" && wf-recorder ${audioCmd} -g "$(slurp)" -f "${expandedDir}/${filename}"`;
        } else {
            recordCmd = `mkdir -p "${expandedDir}" && wf-recorder ${audioCmd} -f "${expandedDir}/${filename}"`;
        }

        Quickshell.execDetached(["sh", "-c", recordCmd]);
        recModule.isRecording = true;
        root.isScreenRecording = true;
        recModule.recordSeconds = 0;
        recModule.isMicDropdownOpen = false;
        root.activeMode = "idle";
    }

    function stopRecording() {
        Quickshell.execDetached(["sh", "-c", "killall -s SIGINT wf-recorder || killall wf-recorder"]);
        recModule.isRecording = false;
        root.isScreenRecording = false;
        recModule.recordSeconds = 0;
    }

    // ========================================================
    // 3. MATERIAL DESIGN 3 HERO CARD
    // ========================================================
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: recModule.isRecording ? 104 : 80
        radius: 16
        color: recModule.isRecording ? recModule.colRedContainer : recModule.colCard
        border.width: 1
        border.color: recModule.isRecording ? Qt.rgba(recModule.colRed.r, recModule.colRed.g, recModule.colRed.b, 0.45) : recModule.colBorder
        Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Top Status Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Avatar Container (Material 3 Squircle)
                Rectangle {
                    width: 44; height: 44
                    radius: 14
                    color: recModule.isRecording ? Qt.rgba(recModule.colRed.r, recModule.colRed.g, recModule.colRed.b, 0.28) : recModule.colAccentContainer
                    border.width: 1
                    border.color: recModule.isRecording ? recModule.colRed : Qt.rgba(recModule.colAccent.r, recModule.colAccent.g, recModule.colAccent.b, 0.25)
                    Behavior on color { ColorAnimation { duration: 160 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: recModule.isRecording ? "videocam" : "screen_record"
                        iconSize: 24
                        color: recModule.isRecording ? recModule.colRed : recModule.colAccent
                    }
                }

                // Title + Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: recModule.isRecording ? "Recording in Progress" : "Screen Recorder"
                        font.family: "Rubik"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: recModule.colTextPrimary
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: recModule.isRecording 
                            ? ("Elapsed: " + recModule.formatTime(recModule.recordSeconds) + " • 60 FPS • " + (recModule.recordAudio ? "Audio On" : "Muted"))
                            : "WF-Recorder • 60 FPS • Hardware Accelerated"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        color: recModule.colTextSecondary
                        elide: Text.ElideRight
                    }
                }

                // Material 3 State Badge
                Rectangle {
                    radius: 12
                    color: recModule.isRecording ? Qt.rgba(recModule.colRed.r, recModule.colRed.g, recModule.colRed.b, 0.24) : recModule.colAccentContainer
                    border.width: 1
                    border.color: recModule.isRecording ? recModule.colRed : Qt.rgba(recModule.colAccent.r, recModule.colAccent.g, recModule.colAccent.b, 0.3)
                    implicitWidth: statusBadgeRow.implicitWidth + 16
                    implicitHeight: 24

                    Row {
                        id: statusBadgeRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 7; height: 7; radius: 3.5
                            anchors.verticalCenter: parent.verticalCenter
                            color: recModule.isRecording ? recModule.colRed : recModule.colAccent

                            SequentialAnimation on opacity {
                                running: recModule.isRecording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }

                        Text {
                            text: recModule.isRecording ? "RECORDING" : "STANDBY"
                            font.family: "Rubik"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: recModule.isRecording ? recModule.colRed : recModule.colAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Bottom Material 3 Metadata Chips (visible in Standby)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !recModule.isRecording

                // Chip 1: Save Directory
                Rectangle {
                    height: 24
                    radius: 8
                    color: chipDirMouse.containsMouse ? recModule.colCardHover : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: chipDirMouse.containsMouse ? recModule.colBorderHover : recModule.colBorder
                    implicitWidth: chipDirRow.implicitWidth + 14
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: chipDirRow
                        anchors.centerIn: parent
                        spacing: 5
                        MaterialSymbol {
                            text: "folder_open"
                            iconSize: 13
                            color: recModule.colAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: recModule.saveDirectory
                            font.family: "Rubik"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: recModule.colTextSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: chipDirMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["xdg-open", recModule.saveDirectory.replace(/^~/, Quickshell.env("HOME"))])
                    }
                }

                // Chip 2: Audio Status
                Rectangle {
                    height: 24
                    radius: 8
                    color: recModule.recordAudio ? recModule.colAccentContainer : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: recModule.recordAudio ? Qt.rgba(recModule.colAccent.r, recModule.colAccent.g, recModule.colAccent.b, 0.35) : recModule.colBorder
                    implicitWidth: chipAudioRow.implicitWidth + 14

                    Row {
                        id: chipAudioRow
                        anchors.centerIn: parent
                        spacing: 5
                        MaterialSymbol {
                            text: recModule.recordAudio ? "mic" : "mic_off"
                            iconSize: 13
                            color: recModule.recordAudio ? recModule.colAccent : recModule.colTextMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: recModule.recordAudio ? recModule.selectedSourceName : "Audio Off"
                            font.family: "Rubik"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: recModule.recordAudio ? recModule.colAccent : recModule.colTextSecondary
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Chip 3: Disk Free Space
                Rectangle {
                    height: 24
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: recModule.colBorder
                    implicitWidth: chipSpaceRow.implicitWidth + 14

                    Row {
                        id: chipSpaceRow
                        anchors.centerIn: parent
                        spacing: 5
                        MaterialSymbol {
                            text: "storage"
                            iconSize: 13
                            color: recModule.colTextMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: recModule.freeDiskSpace
                            font.family: "Rubik"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.features: ({ "tnum": 1 })
                            color: recModule.colTextSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // ========================================================
    // 4. ACTION CONTROLS: CAPTURE MODES (Material 3 Cards)
    // ========================================================
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: !recModule.isRecording

        // 1. Full Screen Card
        Rectangle {
            Layout.fillWidth: true
            height: 58
            radius: 14
            color: fullMouse.containsMouse ? recModule.colCardHover : recModule.colCard
            border.width: 1
            border.color: fullMouse.containsMouse ? recModule.colBorderHover : recModule.colBorder
            scale: fullMouse.pressed ? 0.98 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 90 } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Rectangle {
                    width: 36; height: 36
                    radius: 10
                    color: recModule.colAccentContainer
                    border.width: 0

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "fullscreen"
                        iconSize: 22
                        color: recModule.colAccent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Full Screen"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: recModule.colTextPrimary
                    }
                    Text {
                        text: "Entire display"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        color: recModule.colTextSecondary
                    }
                }
            }

            MouseArea {
                id: fullMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: recModule.startRecording(false)
            }
        }

        // 2. Select Area Card
        Rectangle {
            Layout.fillWidth: true
            height: 58
            radius: 14
            color: areaMouse.containsMouse ? recModule.colCardHover : recModule.colCard
            border.width: 1
            border.color: areaMouse.containsMouse ? recModule.colBorderHover : recModule.colBorder
            scale: areaMouse.pressed ? 0.98 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 90 } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Rectangle {
                    width: 36; height: 36
                    radius: 10
                    color: recModule.colAccentContainer
                    border.width: 0

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "crop_free"
                        iconSize: 20
                        color: recModule.colAccent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Select Area"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: recModule.colTextPrimary
                    }
                    Text {
                        text: "Crop with Slurp"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        color: recModule.colTextSecondary
                    }
                }
            }

            MouseArea {
                id: areaMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: recModule.startRecording(true)
            }
        }
    }

    // ========================================================
    // 5. AUDIO & MICROPHONE SELECTION CARD (Material 3 Switch)
    // ========================================================
    Rectangle {
        Layout.fillWidth: true
        visible: !recModule.isRecording
        radius: 14
        color: recModule.colCard
        border.width: 1
        border.color: recModule.colBorder
        implicitHeight: recModule.isMicDropdownOpen ? (50 + Math.min(3, micSourcesModel.count) * 34 + 8) : 50
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // Top Switch Row
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 10

                Rectangle {
                    width: 30; height: 30
                    radius: 9
                    color: recModule.recordAudio ? recModule.colAccentContainer : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 0

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: recModule.recordAudio ? "mic" : "mic_off"
                        iconSize: 17
                        color: recModule.recordAudio ? recModule.colAccent : recModule.colTextMuted
                    }
                }

                Text {
                    text: "Microphone Audio"
                    font.family: "Rubik"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: recModule.colTextPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // Selected Device Pill Dropdown Trigger
                Rectangle {
                    visible: recModule.recordAudio
                    height: 26
                    radius: 8
                    color: micSelectMouse.containsMouse ? recModule.colCardHover : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: micSelectMouse.containsMouse ? recModule.colBorderHover : recModule.colBorder
                    implicitWidth: Math.min(170, micSelectRow.implicitWidth + 18)

                    RowLayout {
                        id: micSelectRow
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: recModule.selectedSourceName
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.bold: true
                            color: recModule.colAccent
                            elide: Text.ElideRight
                        }

                        MaterialSymbol {
                            text: recModule.isMicDropdownOpen ? "expand_less" : "expand_more"
                            iconSize: 16
                            color: recModule.colTextSecondary
                        }
                    }

                    MouseArea {
                        id: micSelectMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: recModule.isMicDropdownOpen = !recModule.isMicDropdownOpen
                    }
                }

                // Material 3 Switch
                Item {
                    implicitWidth: 42
                    implicitHeight: 24

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: recModule.recordAudio ? recModule.colAccent : Qt.rgba(1, 1, 1, 0.14)
                        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        Rectangle {
                            width: 18; height: 18
                            radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: recModule.recordAudio ? parent.width - width - 3 : 3
                            color: recModule.recordAudio ? "#16161e" : recModule.colTextPrimary
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            recModule.recordAudio = !recModule.recordAudio;
                            if (!recModule.recordAudio) recModule.isMicDropdownOpen = false;
                        }
                    }
                }
            }

            // Expanded Mic Devices List
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(3, micSourcesModel.count) * 34
                visible: recModule.recordAudio && recModule.isMicDropdownOpen
                clip: true
                spacing: 3
                model: micSourcesModel

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 31
                    radius: 8
                    property bool isSelected: (model.sourceId === recModule.selectedSourceId)
                    color: isSelected ? recModule.colAccentContainer : (micItemMouse.containsMouse ? recModule.colCardHover : "transparent")
                    border.width: isSelected ? 1 : 0
                    border.color: isSelected ? recModule.colAccent : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 8

                        MaterialSymbol {
                            text: isSelected ? "radio_button_checked" : "radio_button_unchecked"
                            iconSize: 16
                            color: isSelected ? recModule.colAccent : recModule.colTextMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: model.sourceName
                            color: isSelected ? recModule.colAccent : recModule.colTextPrimary
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.bold: isSelected
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: micItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            recModule.selectedSourceId = model.sourceId;
                            recModule.selectedSourceName = model.sourceName;
                            recModule.isMicDropdownOpen = false;
                        }
                    }
                }
            }
        }
    }

    // ========================================================
    // 6. UTILITY ROW: REGION SCREENSHOT & OPEN FOLDER (M3 Tonal)
    // ========================================================
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: !recModule.isRecording

        // Screenshot Region Button
        Rectangle {
            Layout.fillWidth: true
            height: 34
            radius: 10
            color: snapMouse.containsMouse ? recModule.colCardHover : Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: snapMouse.containsMouse ? recModule.colBorderHover : recModule.colBorder
            scale: snapMouse.pressed ? 0.98 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 90 } }

            Row {
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: "photo_camera"
                    iconSize: 15
                    color: recModule.colAccent
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Region Screenshot"
                    font.family: "Rubik"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: recModule.colTextPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: snapMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.activeMode = "idle";
                    Quickshell.execDetached(["sh", "-c", `
                        mkdir -p ~/Pictures/Screenshots
                        F="$HOME/Pictures/Screenshots/screenshot_$(date +%Y%m%d_%H%M%S).png"
                        grim -g "$(slurp)" "$F" && wl-copy < "$F"
                    `]);
                }
            }
        }

        // Open Videos Folder Button
        Rectangle {
            Layout.fillWidth: true
            height: 34
            radius: 10
            color: folderMouse.containsMouse ? recModule.colCardHover : Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: folderMouse.containsMouse ? recModule.colBorderHover : recModule.colBorder
            scale: folderMouse.pressed ? 0.98 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 90 } }

            Row {
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: "folder_open"
                    iconSize: 15
                    color: recModule.colTextSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Open Videos"
                    font.family: "Rubik"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: recModule.colTextPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: folderMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    Quickshell.execDetached(["xdg-open", recModule.saveDirectory.replace(/^~/, Quickshell.env("HOME"))]);
                }
            }
        }
    }

    // ========================================================
    // 7. RECORDING ACTIVE: PROMINENT MATERIAL 3 STOP BUTTON
    // ========================================================
    Rectangle {
        Layout.fillWidth: true
        height: 48
        radius: 14
        visible: recModule.isRecording
        color: stopMouse.containsMouse ? Qt.darker(recModule.colRed, 1.15) : recModule.colRed
        border.width: 0
        scale: stopMouse.pressed ? 0.98 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            MaterialSymbol {
                text: "stop_circle"
                iconSize: 22
                color: "white"
            }

            Text {
                text: "Stop Recording"
                font.family: "Rubik"
                font.pixelSize: 13
                font.weight: Font.Bold
                color: "white"
            }

            Rectangle {
                width: timePillText.implicitWidth + 14
                height: 22
                radius: 11
                color: Qt.rgba(0, 0, 0, 0.28)
                border.width: 0

                Text {
                    id: timePillText
                    anchors.centerIn: parent
                    text: recModule.formatTime(recModule.recordSeconds)
                    font.family: "Rubik"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                    color: "white"
                }
            }
        }

        MouseArea {
            id: stopMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: recModule.stopRecording()
        }
    }
}
