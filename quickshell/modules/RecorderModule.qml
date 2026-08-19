import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: recorderModule
    spacing: 10

    property string saveDirectory: "~/Videos"
    property bool recordAudio: false
    property string selectedSourceId: ""
    property string selectedSourceName: "Default Microphone"
    property bool isMicDropdownOpen: false
    property bool isRecording: false
    property int recordSeconds: 0

    ListModel { id: micSourcesModel }

    // Query all available recording sources (excluding desktop sink monitors)
    Process {
        id: micScanner
        running: root.activeMode === "recorder"
        command: ["sh", "-c", `
            python3 -c "
import subprocess, re

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
        
        # When both fields are populated
        if current_name and current_desc:
            # Filter out monitor sources so only actual microphones / input devices show
            if not current_name.endswith('.monitor'):
                sources.append(f'{current_name}|||{current_desc}')
            current_name = None
            current_desc = None

    print('\\n'.join(sources))
except Exception as e:
    pass
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                micSourcesModel.clear();
                // Add default source option
                micSourcesModel.append({
                    "sourceId": "@DEFAULT_SOURCE@",
                    "sourceName": "Default System Mic"
                });

                var lines = this.text.trim().split("\n");
                var defaultChosen = (recorderModule.selectedSourceId !== "");

                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 2) {
                        micSourcesModel.append({
                            "sourceId": parts[0].trim(),
                            "sourceName": parts[1].trim()
                        });
                        if (!defaultChosen && i === 0) {
                            recorderModule.selectedSourceId = parts[0].trim();
                            recorderModule.selectedSourceName = parts[1].trim();
                        }
                    }
                }

                if (recorderModule.selectedSourceId === "") {
                    recorderModule.selectedSourceId = "@DEFAULT_SOURCE@";
                    recorderModule.selectedSourceName = "Default System Mic";
                }
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
                recorderModule.isRecording = running;
                root.isScreenRecording = running;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: if (!statusChecker.running) statusChecker.running = true
    }

    Timer {
        id: recordingTimer
        interval: 1000
        running: recorderModule.isRecording
        repeat: true
        onTriggered: recorderModule.recordSeconds++
    }

    function formatTime(totalSec) {
        var mins = Math.floor(totalSec / 60);
        var secs = totalSec % 60;
        return (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    function startRecording(regionMode) {
        var expandedDir = saveDirectory.replace(/^~/, "$HOME");
        var filename = "recording_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + ".mp4";
        
        var audioCmd = "";
        if (recorderModule.recordAudio) {
            var targetSrc = recorderModule.selectedSourceId !== "" ? recorderModule.selectedSourceId : "@DEFAULT_SOURCE@";
            audioCmd = "--audio=" + targetSrc;
        }
        
        var recordCmd = "";
        if (regionMode) {
            recordCmd = `mkdir -p ${expandedDir} && wf-recorder ${audioCmd} -g "$(slurp)" -f ${expandedDir}/${filename}`;
        } else {
            recordCmd = `mkdir -p ${expandedDir} && wf-recorder ${audioCmd} -f ${expandedDir}/${filename}`;
        }

        Quickshell.execDetached(["sh", "-c", recordCmd]);
        recorderModule.isRecording = true;
        root.isScreenRecording = true;
        recorderModule.recordSeconds = 0;
        recorderModule.isMicDropdownOpen = false;
        root.activeMode = "idle";
    }

    function stopRecording() {
        Quickshell.execDetached(["sh", "-c", "killall -s SIGINT wf-recorder || killall wf-recorder"]);
        recorderModule.isRecording = false;
        root.isScreenRecording = false;
        recorderModule.recordSeconds = 0;
    }

    // Header
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "Screen Recorder"
            font.pixelSize: 15
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: recorderModule.isRecording
            width: 82; height: 24; radius: 6
            color: "#f44336"

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                Rectangle { width: 6; height: 6; radius: 3; color: "white" }
                Text {
                    text: recorderModule.formatTime(recorderModule.recordSeconds)
                    color: "white"
                    font.bold: true; font.pixelSize: 11
                }
            }
        }
    }

    // Save Directory Input Card
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: 8
        color: Theme.colors.card_bg ?? "#1f2335"
        border.width: 1
        border.color: Theme.colors.border ?? "#16161e"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Text {
                text: "Save Directory"
                font.pixelSize: 10
                font.bold: true
                color: Theme.colors.text_secondary ?? "#565f89"
            }

            TextField {
                id: dirInput
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                text: recorderModule.saveDirectory
                color: Theme.colors.text_primary ?? "white"
                font.pixelSize: 12
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                onTextChanged: recorderModule.saveDirectory = text.trim() === "" ? "~/Pictures/Video" : text

                background: Rectangle {
                    color: Theme.colors.bg ?? "#16161e"
                    radius: 6
                    border.width: 1
                    border.color: dirInput.activeFocus ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")
                }
            }
        }
    }

    // Audio & Mic Device Card
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: {
            if (!recorderModule.recordAudio) return 40;
            return recorderModule.isMicDropdownOpen ? (74 + Math.min(3, micSourcesModel.count) * 32) : 74;
        }
        radius: 8
        color: Theme.colors.card_bg ?? "#1f2335"
        border.width: 1
        border.color: Theme.colors.border ?? "#16161e"
        clip: true

        Behavior on Layout.preferredHeight {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            // Toggle Audio Row
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24

                Text {
                    text: "Record Microphone Audio"
                    color: Theme.colors.text_primary ?? "white"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 38; height: 20; radius: 10
                    color: recorderModule.recordAudio ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.hover_bg ?? "#24283b")

                    Rectangle {
                        width: 14; height: 14; radius: 7
                        anchors.verticalCenter: parent.verticalCenter
                        x: recorderModule.recordAudio ? parent.width - width - 3 : 3
                        color: recorderModule.recordAudio ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_secondary ?? "#565f89")
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            recorderModule.recordAudio = !recorderModule.recordAudio;
                            if (!recorderModule.recordAudio) recorderModule.isMicDropdownOpen = false;
                        }
                    }
                }
            }

            // Dropdown Selector Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                visible: recorderModule.recordAudio
                radius: 6
                color: Theme.colors.bg ?? "#16161e"
                border.width: 1
                border.color: recorderModule.isMicDropdownOpen ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "󰍬"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.colors.accent ?? "#7aa2f7"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: recorderModule.selectedSourceName
                        color: Theme.colors.text_primary ?? "white"
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: recorderModule.isMicDropdownOpen ? "󰅃" : "󰅀"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.colors.text_secondary ?? "#565f89"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: recorderModule.isMicDropdownOpen = !recorderModule.isMicDropdownOpen
                }
            }

            // Expanded Mic Devices List
            ListView {
                id: micList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(3, micSourcesModel.count) * 32
                visible: recorderModule.recordAudio && recorderModule.isMicDropdownOpen
                clip: true
                spacing: 3
                model: micSourcesModel

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 28
                    radius: 5
                    property bool isSelected: (model.sourceId === recorderModule.selectedSourceId)
                    color: isSelected ? (Theme.colors.hover_bg ?? "#24283b") : (micItemMouse.containsMouse ? (Theme.colors.bg ?? "#16161e") : "transparent")
                    border.width: isSelected ? 1 : 0
                    border.color: Theme.colors.accent ?? "#7aa2f7"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            text: isSelected ? "󰄲" : "󰄱"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                        }

                        Text {
                            Layout.fillWidth: true
                            text: model.sourceName
                            color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "white")
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: micItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            recorderModule.selectedSourceId = model.sourceId;
                            recorderModule.selectedSourceName = model.sourceName;
                            recorderModule.isMicDropdownOpen = false;
                        }
                    }
                }
            }
        }
    }

    // Action Controls
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 8
            visible: !recorderModule.isRecording
            color: fullMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335")
            border.width: 1; border.color: Theme.colors.border_hover ?? "#7aa2f7"

            RowLayout {
                anchors.centerIn: parent; spacing: 6
                Text { text: "󰍹"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.colors.accent ?? "#7aa2f7" }
                Text { text: "Full Screen"; color: Theme.colors.text_primary ?? "white"; font.bold: true; font.pixelSize: 11 }
            }
            MouseArea { id: fullMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: recorderModule.startRecording(false) }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 8
            visible: !recorderModule.isRecording
            color: areaMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335")
            border.width: 1; border.color: Theme.colors.border_hover ?? "#7aa2f7"

            RowLayout {
                anchors.centerIn: parent; spacing: 6
                Text { text: "󰒉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.colors.accent ?? "#7aa2f7" }
                Text { text: "Select Area"; color: Theme.colors.text_primary ?? "white"; font.bold: true; font.pixelSize: 11 }
            }
            MouseArea { id: areaMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: recorderModule.startRecording(true) }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 8
            visible: recorderModule.isRecording
            color: "#f44336"

            RowLayout {
                anchors.centerIn: parent; spacing: 6
                Text { text: "󰐥"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: "white" }
                Text { text: "Stop Recording"; color: "white"; font.bold: true; font.pixelSize: 12 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: recorderModule.stopRecording() }
        }
    }
}
