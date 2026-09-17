import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: recModule
    spacing: 8
    Layout.fillWidth: true

    // Material UI Solid Polygon Tokens (Zero borders, pure tonal surfaces)
    readonly property color colSurface: "#000000"
    readonly property color colCard: Theme.colors.card_bg ?? "#181c24"
    readonly property color colCardHover: Theme.colors.hover_bg ?? "#222834"
    readonly property color colCardActive: Qt.alpha(recModule.colAccent, 0.16)
    readonly property color colChipBg: Theme.colors.hover_bg ?? "#222834"
    readonly property color colText: Theme.colors.text_primary ?? "#eceff4"
    readonly property color colSubtext: Theme.colors.text_secondary ?? "#d8dee9"
    readonly property color colMuted: Theme.colors.text_muted ?? "#81a1c1"
    readonly property color colAccent: Theme.colors.accent ?? "#88c0d0"
    readonly property color colGreen: ({ nord: "#a3be8c", dracula: "#50fa7b", catppuccin: "#a6e3a1", everforest: "#a7c080", "rose-pine": "#9ccfd8" })[Theme.currentThemeName] ?? "#30d158"
    readonly property color colRed: ({ nord: "#bf616a", dracula: "#ff5555", catppuccin: "#f38ba8", everforest: "#e67e80", "rose-pine": "#eb6f92" })[Theme.currentThemeName] ?? "#ff453a"

    property string saveDirectory: "~/Videos"
    property bool recordAudio: false
    property string selectedSourceId: ""
    property string selectedSourceName: "Default Microphone"
    property bool isMicDropdownOpen: false
    property bool isRecording: false
    property int recordSeconds: 0
    property string freeDiskSpace: "114G Free"

    ListModel { id: micSourcesModel }

    // Query available audio input sources
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

    // Disk free space check
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

    // Check background recording status
    Process {
        id: statusChecker
        running: root.activeMode === "recorder" || root.activeMode === "idle" || root.activeMode === "hover"
        command: ["sh", "-c", "pgrep -x wf-recorder > /dev/null && echo 'running' || echo 'stopped'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var running = (this.text.trim() === "running");
                recModule.isRecording = running;
                root.isScreenRecording = running;
            }
        }
    }

    Timer {
        interval: 1800
        running: true
        repeat: true
        onTriggered: {
            if (!statusChecker.running) statusChecker.running = true;
            if (root.activeMode === "recorder" && !diskChecker.running) diskChecker.running = true;
        }
    }

    Timer {
        id: recordingTimer
        interval: 1000
        running: recModule.isRecording
        repeat: true
        onTriggered: recModule.recordSeconds++
    }

    function formatTime(totalSec) {
        var mins = Math.floor(totalSec / 60);
        var secs = totalSec % 60;
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
    // 1. HERO RECORDER CARD (Material UI Solid Surface, Zero Borders)
    // ========================================================
    Rectangle {
        Layout.fillWidth: true
        height: 94
        radius: 14
        color: recModule.colCard
        border.width: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 8

            // Top Status Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Tactile Back to Utility Button
                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: recBackMouse.containsMouse ? recModule.colCardHover : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    scale: recBackMouse.pressed ? 0.90 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: recModule.colText
                    }

                    MouseArea {
                        id: recBackMouse
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.switchMode("utility", true)
                    }
                }

                // Squircle Icon Badge
                Rectangle {
                    width: 38
                    height: 38
                    radius: 11
                    color: recModule.isRecording ? Qt.alpha(recModule.colRed, 0.22) : recModule.colChipBg
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: recModule.isRecording ? "󰐥" : "󰕧"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
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
                        font.family: "Noto Sans"
                        font.pixelSize: 13
                        font.bold: true
                        color: recModule.colText
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: recModule.isRecording 
                            ? ("Elapsed: " + recModule.formatTime(recModule.recordSeconds) + " • 60 FPS")
                            : "H.264 MP4 • Hardware Accelerated"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        color: recModule.colSubtext
                        elide: Text.ElideRight
                    }
                }

                // Solid Status Pill
                Rectangle {
                    radius: 10
                    color: recModule.isRecording ? Qt.alpha(recModule.colRed, 0.22) : Qt.alpha(recModule.colAccent, 0.16)
                    border.width: 0
                    implicitWidth: statusRow.implicitWidth + 14
                    implicitHeight: 22

                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: recModule.isRecording ? recModule.colRed : recModule.colAccent

                            SequentialAnimation on opacity {
                                running: recModule.isRecording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            text: recModule.isRecording ? "RECORDING" : "STANDBY"
                            font.family: "Rubik"
                            font.pixelSize: 10
                            font.bold: true
                            color: recModule.isRecording ? recModule.colRed : recModule.colAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Bottom Tonal Metadata Chips Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Chip 1: Save Directory
                Rectangle {
                    height: 22
                    radius: 6
                    color: recModule.colChipBg
                    border.width: 0
                    implicitWidth: chipDirRow.implicitWidth + 12

                    Row {
                        id: chipDirRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰉋"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: recModule.colMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: recModule.saveDirectory
                            font.family: "Rubik"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: recModule.colSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Chip 2: Audio Mode
                Rectangle {
                    height: 22
                    radius: 6
                    color: recModule.recordAudio ? Qt.alpha(recModule.colAccent, 0.2) : recModule.colChipBg
                    border.width: 0
                    implicitWidth: chipAudioRow.implicitWidth + 12

                    Row {
                        id: chipAudioRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: recModule.recordAudio ? "󰍬" : "󰝟"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: recModule.recordAudio ? recModule.colAccent : recModule.colMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: recModule.recordAudio ? recModule.selectedSourceName : "No Audio"
                            font.family: "Rubik"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: recModule.recordAudio ? recModule.colAccent : recModule.colSubtext
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Chip 3: Free Disk Space
                Rectangle {
                    height: 22
                    radius: 6
                    color: recModule.colChipBg
                    border.width: 0
                    implicitWidth: chipSpaceRow.implicitWidth + 12

                    Row {
                        id: chipSpaceRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰋊"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: recModule.colMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: recModule.freeDiskSpace
                            font.family: "Rubik"
                            font.pixelSize: 10
                            font.bold: true
                            font.features: ({ "tnum": 1 })
                            color: recModule.colSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // ========================================================
    // 2. AUDIO & MICROPHONE SELECTION (Solid M3 Controls, Zero Borders)
    // ========================================================
    Rectangle {
        Layout.fillWidth: true
        visible: !recModule.isRecording
        radius: 12
        color: recModule.colCard
        border.width: 0
        implicitHeight: recModule.isMicDropdownOpen ? (46 + Math.min(3, micSourcesModel.count) * 32 + 8) : 46
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            // Top Audio Row
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 8

                // Mic Icon badge
                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: recModule.recordAudio ? Qt.alpha(recModule.colAccent, 0.18) : recModule.colChipBg
                    border.width: 0
                    Text {
                        anchors.centerIn: parent
                        text: recModule.recordAudio ? "󰍬" : "󰝟"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: recModule.recordAudio ? recModule.colAccent : recModule.colMuted
                    }
                }

                Text {
                    text: "Microphone Audio"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.bold: true
                    color: recModule.colText
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // Selected Device Pill Dropdown Trigger
                Rectangle {
                    visible: recModule.recordAudio
                    height: 26
                    radius: 8
                    color: micSelectMouse.containsMouse ? recModule.colCardHover : recModule.colChipBg
                    border.width: 0
                    implicitWidth: Math.min(170, micSelectRow.implicitWidth + 16)

                    RowLayout {
                        id: micSelectRow
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 5

                        Text {
                            Layout.fillWidth: true
                            text: recModule.selectedSourceName
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.bold: true
                            color: recModule.colAccent
                            elide: Text.ElideRight
                        }

                        Text {
                            text: recModule.isMicDropdownOpen ? "󰅃" : "󰅀"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: recModule.colSubtext
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

                // Material You Solid Switch
                Item {
                    implicitWidth: 40
                    implicitHeight: 22

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: recModule.recordAudio ? recModule.colAccent : recModule.colChipBg
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            x: recModule.recordAudio ? parent.width - width - 3 : 3
                            color: recModule.recordAudio ? recModule.colSurface : recModule.colSubtext
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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
                Layout.preferredHeight: Math.min(3, micSourcesModel.count) * 32
                visible: recModule.recordAudio && recModule.isMicDropdownOpen
                clip: true
                spacing: 3
                model: micSourcesModel

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 29
                    radius: 7
                    property bool isSelected: (model.sourceId === recModule.selectedSourceId)
                    color: isSelected ? Qt.alpha(recModule.colAccent, 0.16) : (micItemMouse.containsMouse ? recModule.colCardHover : "transparent")
                    border.width: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: isSelected ? "󰄲" : "󰄱"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: isSelected ? recModule.colAccent : recModule.colMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: model.sourceName
                            color: isSelected ? recModule.colAccent : recModule.colText
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
    // 3. ACTION CONTROLS (Solid Cards, Zero Borders)
    // ========================================================
    // When NOT recording: Full Screen + Area Capture Cards
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: !recModule.isRecording

        // Full Screen Record Button
        Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: 12
            color: fullMouse.containsMouse ? recModule.colCardHover : recModule.colCard
            border.width: 0

            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: recModule.colChipBg
                    border.width: 0
                    Text {
                        anchors.centerIn: parent
                        text: "󰍹"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: recModule.colAccent
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Text {
                        text: "Full Screen"
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                        font.bold: true
                        color: recModule.colText
                    }
                    Text {
                        text: "Entire Display"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        color: recModule.colSubtext
                    }
                }
            }

            MouseArea {
                id: fullMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: recModule.startRecording(false)
            }
        }

        // Select Area Record Button
        Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: 12
            color: areaMouse.containsMouse ? recModule.colCardHover : recModule.colCard
            border.width: 0

            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: recModule.colChipBg
                    border.width: 0
                    Text {
                        anchors.centerIn: parent
                        text: "󰒉"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: recModule.colAccent
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Text {
                        text: "Select Area"
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                        font.bold: true
                        color: recModule.colText
                    }
                    Text {
                        text: "Crop with Slurp"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        color: recModule.colSubtext
                    }
                }
            }

            MouseArea {
                id: areaMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: recModule.startRecording(true)
            }
        }
    }

    // Utility Quick Action Chips (Screenshot & Open Videos Folder)
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: !recModule.isRecording

        // Quick Screenshot Button
        Rectangle {
            Layout.fillWidth: true
            height: 28
            radius: 8
            color: snapMouse.containsMouse ? recModule.colCardHover : recModule.colChipBg
            border.width: 0

            Row {
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: "󰹑"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: recModule.colAccent
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Screenshot Region"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.bold: true
                    color: recModule.colText
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
            height: 28
            radius: 8
            color: folderMouse.containsMouse ? recModule.colCardHover : recModule.colChipBg
            border.width: 0

            Row {
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: "󰉋"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: recModule.colSubtext
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Open Videos"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.bold: true
                    color: recModule.colText
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

    // When RECORDING: Prominent Solid Stop Recording Button
    Rectangle {
        Layout.fillWidth: true
        height: 46
        radius: 12
        visible: recModule.isRecording
        color: stopMouse.containsMouse ? Qt.darker(recModule.colRed, 1.15) : recModule.colRed
        border.width: 0

        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "󰐥"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: "white"
            }

            Text {
                text: "Stop Recording"
                font.family: "Noto Sans"
                font.pixelSize: 13
                font.bold: true
                color: "white"
            }

            Rectangle {
                width: timePillText.implicitWidth + 12
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
                    font.bold: true
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
