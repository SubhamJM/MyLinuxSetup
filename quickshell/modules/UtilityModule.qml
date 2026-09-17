import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../"

Item {
    id: utilModule
    Layout.fillWidth: true
    Layout.fillHeight: true

    // ========================================================
    // STATE PROPERTIES & PROCESSES
    // ========================================================
    property bool nightLightActive: false
    property bool caffeineActive: false
    property bool audioMuted: false
    property real audioVolume: 0.5
    property real displayBrightness: 0.5
    property bool isDraggingVolume: false
    property bool isDraggingBrightness: false

    // Dynamic expansion tracking: smoothly interpolates from 0.0 to 1.0 as the utility section opens
    property real openProgress: (root.activeMode === "utility" || isDraggingVolume || isDraggingBrightness) ? 1.0 : 0.0
    Behavior on openProgress {
        enabled: root.activeMode === "utility" && !utilModule.isDraggingVolume && !utilModule.isDraggingBrightness
        NumberAnimation {
            duration: NotchConfig.animNotchResize
            easing.type: Easing.OutCubic
        }
    }

    // Animated values for smooth slider response when already open (e.g. mouse wheel or background updates)
    property real animatedVolume: utilModule.audioMuted ? 0.0 : utilModule.audioVolume
    Behavior on animatedVolume {
        enabled: !utilModule.isDraggingVolume && utilModule.openProgress >= 0.95
        NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
    }

    property real animatedBrightness: utilModule.displayBrightness
    Behavior on animatedBrightness {
        enabled: !utilModule.isDraggingBrightness && utilModule.openProgress >= 0.95
        NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
    }

    // Sync state when module becomes visible
    onVisibleChanged: {
        if (visible) {
            checkNightLight.running = true;
            if (!fetchVolumeProcess.running && !utilModule.isDraggingVolume) fetchVolumeProcess.running = true;
            if (!fetchBrightnessProcess.running && !utilModule.isDraggingBrightness) fetchBrightnessProcess.running = true;
        }
    }

    Component.onCompleted: {
        checkNightLight.running = true;
        fetchVolumeProcess.running = true;
        fetchBrightnessProcess.running = true;
    }

    // 1. Night Light Check (hyprsunset)
    Process {
        id: checkNightLight
        running: false
        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo 'active' || echo 'inactive'"]
        stdout: StdioCollector {
            onStreamFinished: {
                utilModule.nightLightActive = (this.text.trim() === "active");
            }
        }
    }

    Timer {
        id: nightLightCheckTimer
        interval: 300
        repeat: false
        onTriggered: checkNightLight.running = true
    }

    function toggleNightLight() {
        if (nightLightActive) {
            Quickshell.execDetached(["sh", "-c", "killall -9 hyprsunset 2>/dev/null"]);
            nightLightActive = false;
        } else {
            Quickshell.execDetached(["sh", "-c", "killall -9 hyprsunset 2>/dev/null; hyprsunset -t 4500"]);
            nightLightActive = true;
        }
        nightLightCheckTimer.restart();
    }

    // 2. Caffeine (Systemd Idle Inhibitor)
    Process {
        id: caffeineInhibitor
        running: false
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Caffeine", "sleep", "infinity"]
    }

    function toggleCaffeine() {
        if (caffeineActive) {
            caffeineInhibitor.running = false;
            caffeineActive = false;
        } else {
            caffeineInhibitor.running = true;
            caffeineActive = true;
        }
    }

    // 3. Audio Volume (wpctl)
    Process {
        id: fetchVolumeProcess
        running: false
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = this.text.trim();
                var isMuted = txt.includes("[MUTED]");
                utilModule.audioMuted = isMuted;
                var parts = txt.split(/\s+/);
                if (parts.length >= 2 && !utilModule.isDraggingVolume) {
                    var v = parseFloat(parts[1]);
                    if (!isNaN(v)) {
                        var clamped = Math.max(0.0, Math.min(1.0, v));
                        if (Math.abs(clamped - utilModule.audioVolume) > 0.005) {
                            utilModule.audioVolume = clamped;
                        }
                    }
                }
            }
        }
    }

    function setVolume(ratio) {
        var v = Math.max(0.0, Math.min(1.0, ratio));
        utilModule.audioVolume = v;
        utilModule.audioMuted = (v <= 0.001);
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)]);
    }

    function toggleMute() {
        utilModule.audioMuted = !utilModule.audioMuted;
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        fetchVolumeProcess.running = true;
    }

    // 4. Display Brightness (brightnessctl)
    Process {
        id: fetchBrightnessProcess
        running: false
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = parseInt(this.text.trim());
                if (!isNaN(val) && !utilModule.isDraggingBrightness) {
                    var b = Math.max(0.01, Math.min(1.0, val / 100.0));
                    if (Math.abs(b - utilModule.displayBrightness) > 0.005) {
                        utilModule.displayBrightness = b;
                    }
                }
            }
        }
    }

    function setBrightness(ratio) {
        var pct = Math.max(1, Math.min(100, Math.round(ratio * 100)));
        utilModule.displayBrightness = pct / 100.0;
        Quickshell.execDetached(["brightnessctl", "set", pct + "%"]);
    }

    // Periodic sync timer for volume & brightness to keep values fresh in background
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (!fetchVolumeProcess.running && !utilModule.isDraggingVolume) fetchVolumeProcess.running = true;
            if (!fetchBrightnessProcess.running && !utilModule.isDraggingBrightness) fetchBrightnessProcess.running = true;
        }
    }

    // Accent color helper (vibrant mint / cyan like in screenshot)
    readonly property color accentColor: Theme.colors.accent ?? "#2dd4bf"
    readonly property color cardColor: Theme.colors.card_bg ?? "#1c1d27"
    readonly property color trackBgColor: "#14151e"

    // ========================================================
    // UI LAYOUT
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        // ===== TOP HEADER BAR =====
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 8

            // Back button
            Rectangle {
                width: 24; height: 24; radius: 12
                color: backMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: 1; border.color: Theme.colors.border ?? "#16161e"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                    color: Theme.colors.text_primary ?? "white"
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.collapseToIdle()
                }
            }

            Rectangle {
                width: 22; height: 22; radius: 11
                color: Qt.rgba(0.18, 0.83, 0.75, 0.15)
                Text {
                    anchors.centerIn: parent
                    text: "󱊖"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                    color: utilModule.accentColor
                }
            }

            Text {
                text: "Control Center"
                font.pixelSize: 13; font.bold: true
                color: Theme.colors.text_primary ?? "#c0caf5"
            }

            Item { Layout.fillWidth: true }

            // Music Island Shortcut Pill
            Rectangle {
                width: 26; height: 26; radius: 13
                color: musicMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335")
                border.width: 1; border.color: Theme.colors.border ?? "#16161e"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                    color: utilModule.accentColor
                }

                MouseArea {
                    id: musicMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("music", true)
                }
            }

            // Power Menu Shortcut Pill
            Rectangle {
                width: 26; height: 26; radius: 13
                color: pwrMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335")
                border.width: 1; border.color: Theme.colors.border ?? "#16161e"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰐥"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                    color: "#f7768e"
                }

                MouseArea {
                    id: pwrMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("powermenu", true)
                }
            }
        }

        // ===== ROW 1: WI-FI PILL | FOCUS PILL | CAFFEINE CIRCLE =====
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            spacing: 8

            // 1. Wi-Fi Split Capsule Pill
            Rectangle {
                id: wifiCapsule
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 23
                color: utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

                readonly property bool isEnabled: typeof wifiMod !== "undefined" ? wifiMod.wifiEnabled : true

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 5; anchors.rightMargin: 12
                    spacing: 8

                    // Circular Toggle Button on the Left
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: wifiCapsule.isEnabled ? utilModule.accentColor : Qt.rgba(1, 1, 1, 0.08)
                        scale: wifiIconMouse.pressed ? 0.92 : (wifiIconMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: (typeof dashMod !== "undefined" && dashMod.activeNetType === "eth") ? "󰈀" :
                                  (!wifiCapsule.isEnabled ? "󰖪" :
                                  ((typeof dashMod !== "undefined" && dashMod.activeNetSignal > 75) ? "󰤨" :
                                  ((typeof dashMod !== "undefined" && dashMod.activeNetSignal > 50) ? "󰤥" :
                                  ((typeof dashMod !== "undefined" && dashMod.activeNetSignal > 25) ? "󰤢" : "󰖩"))))
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                            color: wifiCapsule.isEnabled ? (Theme.colors.bg ?? "#12141c") : (Theme.colors.text_secondary ?? "#565f89")
                        }

                        MouseArea {
                            id: wifiIconMouse
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (typeof wifiMod !== "undefined") {
                                    var target = wifiMod.wifiEnabled ? "off" : "on";
                                    wifiMod.wifiToggler.command = ["sh", "-c", "nmcli radio wifi " + target];
                                    wifiMod.wifiToggler.running = true;
                                    wifiMod.wifiEnabled = !wifiMod.wifiEnabled;
                                }
                            }
                        }
                    }

                    // Text Info (Opens Wi-Fi Manager)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: "Wi-Fi"
                            font.pixelSize: 12; font.bold: true
                            color: Theme.colors.text_primary ?? "white"
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!wifiCapsule.isEnabled) return "Off";
                                if (typeof dashMod !== "undefined" && dashMod.activeNetName !== "") return dashMod.activeNetName;
                                return "Connected";
                            }
                            font.pixelSize: 10
                            color: wifiCapsule.isEnabled ? (Theme.colors.text_secondary ?? "#565f89") : Qt.rgba(1, 1, 1, 0.4)
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.leftMargin: 46
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("wifi", true)
                }
            }

            // 2. Focus / DND Stadium Pill
            Rectangle {
                id: focusCapsule
                Layout.preferredWidth: 140
                Layout.preferredHeight: 46
                radius: 23
                color: utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

                readonly property bool isFocus: root.dndEnabled

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 5; anchors.rightMargin: 10
                    spacing: 8

                    // Circular Button
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: focusCapsule.isFocus ? utilModule.accentColor : Qt.rgba(1, 1, 1, 0.08)
                        scale: focusMouse.pressed ? 0.92 : (focusMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: focusCapsule.isFocus ? "󰂛" : "󰂚"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                            color: focusCapsule.isFocus ? (Theme.colors.bg ?? "#12141c") : (Theme.colors.text_secondary ?? "#565f89")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            text: "Focus"
                            font.pixelSize: 12; font.bold: true
                            color: Theme.colors.text_primary ?? "white"
                        }
                        Text {
                            text: focusCapsule.isFocus ? "On" : "Off"
                            font.pixelSize: 10
                            color: Theme.colors.text_secondary ?? "#565f89"
                        }
                    }
                }

                MouseArea {
                    id: focusMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.dndEnabled = !root.dndEnabled
                }
            }

            // 3. Caffeine / Awake Circle Button
            Rectangle {
                width: 46; height: 46; radius: 23
                color: utilModule.caffeineActive ? utilModule.accentColor : utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                scale: cafCircleMouse.pressed ? 0.92 : (cafCircleMouse.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: utilModule.caffeineActive ? "󰅶" : "󰾪"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                    color: utilModule.caffeineActive ? (Theme.colors.bg ?? "#12141c") : (Theme.colors.text_secondary ?? "#565f89")
                }

                MouseArea {
                    id: cafCircleMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: utilModule.toggleCaffeine()
                }
            }
        }

        // ===== ROW 2: BLUETOOTH PILL | RECORDER PILL | NIGHT LIGHT CIRCLE =====
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            spacing: 8

            // 1. Bluetooth Split Capsule Pill
            Rectangle {
                id: btCapsule
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 23
                color: utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

                readonly property var adapter: typeof Bluetooth !== "undefined" ? Bluetooth.defaultAdapter : null
                readonly property bool isEnabled: adapter ? adapter.enabled : false

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 5; anchors.rightMargin: 12
                    spacing: 8

                    // Circular Toggle Button on the Left
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: btCapsule.isEnabled ? utilModule.accentColor : Qt.rgba(1, 1, 1, 0.08)
                        scale: btIconMouse.pressed ? 0.92 : (btIconMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: btCapsule.isEnabled ? "󰂯" : "󰂲"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                            color: btCapsule.isEnabled ? (Theme.colors.bg ?? "#12141c") : (Theme.colors.text_secondary ?? "#565f89")
                        }

                        MouseArea {
                            id: btIconMouse
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (btCapsule.adapter) {
                                    btCapsule.adapter.enabled = !btCapsule.adapter.enabled;
                                }
                            }
                        }
                    }

                    // Text Info (Opens Bluetooth Manager)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: "Bluetooth"
                            font.pixelSize: 12; font.bold: true
                            color: Theme.colors.text_primary ?? "white"
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!btCapsule.isEnabled) return "Off";
                                if (typeof dashMod !== "undefined" && dashMod.btConnected) return dashMod.btDeviceName;
                                return "Not connected";
                            }
                            font.pixelSize: 10
                            color: btCapsule.isEnabled ? (Theme.colors.text_secondary ?? "#565f89") : Qt.rgba(1, 1, 1, 0.4)
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.leftMargin: 46
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("bluetooth", true)
                }
            }

            // 2. Recorder Stadium Pill
            Rectangle {
                id: recCapsule
                Layout.preferredWidth: 140
                Layout.preferredHeight: 46
                radius: 23
                color: utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)

                readonly property bool isRecording: root.isScreenRecording

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 5; anchors.rightMargin: 10
                    spacing: 8

                    // Circular Button
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: recCapsule.isRecording ? "#f7768e" : Qt.rgba(1, 1, 1, 0.08)
                        scale: recIconMouse.pressed ? 0.92 : (recIconMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: recCapsule.isRecording ? "󰻃" : "󰑋"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                            color: recCapsule.isRecording ? (Theme.colors.bg ?? "#12141c") : "#f7768e"
                        }

                        MouseArea {
                            id: recIconMouse
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (typeof recMod !== "undefined") {
                                    if (root.isScreenRecording) recMod.stopRecording();
                                    else recMod.startRecording();
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            text: "Recorder"
                            font.pixelSize: 12; font.bold: true
                            color: Theme.colors.text_primary ?? "white"
                        }
                        Text {
                            text: recCapsule.isRecording ? "Recording" : "Idle"
                            font.pixelSize: 10
                            color: recCapsule.isRecording ? "#f7768e" : (Theme.colors.text_secondary ?? "#565f89")
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.leftMargin: 46
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("recorder", true)
                }
            }

            // 3. Night Light Circle Button (Moon)
            Rectangle {
                width: 46; height: 46; radius: 23
                color: utilModule.nightLightActive ? "#e0af68" : utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                scale: nlCircleMouse.pressed ? 0.92 : (nlCircleMouse.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰖔"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                    color: utilModule.nightLightActive ? (Theme.colors.bg ?? "#12141c") : (Theme.colors.text_secondary ?? "#565f89")
                }

                MouseArea {
                    id: nlCircleMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: utilModule.toggleNightLight()
                }
            }
        }

        // ===== ROW 3: SOUND CAPSULE SLIDER =====
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            // Label & Value
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 16

                Text {
                    text: "Sound"
                    font.pixelSize: 12; font.bold: true
                    color: Theme.colors.text_primary ?? "white"
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 3
                    Text {
                        text: utilModule.audioMuted ? "Muted" : Math.round(utilModule.audioVolume * 100) + "%"
                        font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                        color: Theme.colors.text_secondary ?? "#565f89"
                    }
                    Text {
                        text: "󰅂"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                        color: Theme.colors.text_secondary ?? "#565f89"
                    }
                }
            }

            // Thick Stadium Capsule Track
            Rectangle {
                id: soundTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 20
                color: utilModule.trackBgColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                clip: true

                // Filled Liquid Bar - dynamically scales with notch expansion
                Rectangle {
                    id: soundFillBar
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, Math.min(parent.width, parent.width * utilModule.animatedVolume * utilModule.openProgress))
                    radius: 20
                    color: utilModule.accentColor
                }

                // Embedded Speaker Icon
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32; height: 32; radius: 16
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: utilModule.audioMuted ? "󰝟" :
                              (utilModule.audioVolume < 0.4 ? "󰕿" :
                              (utilModule.audioVolume < 0.7 ? "󰖀" : "󰕾"))
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                        color: (!utilModule.audioMuted && soundFillBar.width > 26) 
                               ? (Theme.colors.bg ?? "#12141c") 
                               : (utilModule.audioMuted ? "#f7768e" : "white")
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: utilModule.toggleMute()
                    }
                }

                // Drag & Wheel Interaction Area
                MouseArea {
                    id: soundMouse
                    anchors.fill: parent
                    anchors.leftMargin: 38 // Allow clicking icon to mute
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function updatePos(xVal) {
                        var actualX = xVal + 38;
                        var ratio = Math.max(0.0, Math.min(1.0, actualX / soundTrack.width));
                        utilModule.setVolume(ratio);
                    }

                    onPressed: (mouse) => {
                        utilModule.isDraggingVolume = true;
                        updatePos(mouse.x);
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) updatePos(mouse.x);
                    }
                    onReleased: {
                        utilModule.isDraggingVolume = false;
                    }
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        utilModule.setVolume(utilModule.audioVolume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
                    }
                }
            }
        }

        // ===== ROW 4: DISPLAY CAPSULE SLIDER =====
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            // Label & Value
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 16

                Text {
                    text: "Display"
                    font.pixelSize: 12; font.bold: true
                    color: Theme.colors.text_primary ?? "white"
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 3
                    Text {
                        text: Math.round(utilModule.displayBrightness * 100) + "%"
                        font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                        color: Theme.colors.text_secondary ?? "#565f89"
                    }
                    Text {
                        text: "󰅂"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                        color: Theme.colors.text_secondary ?? "#565f89"
                    }
                }
            }

            // Thick Stadium Capsule Track
            Rectangle {
                id: brightTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 20
                color: utilModule.trackBgColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                clip: true

                // Filled Liquid Bar - dynamically scales with notch expansion
                Rectangle {
                    id: brightFillBar
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, Math.min(parent.width, parent.width * utilModule.animatedBrightness * utilModule.openProgress))
                    radius: 20
                    color: utilModule.accentColor
                }

                // Embedded Sun Icon
                Item {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32; height: 32

                    Text {
                        anchors.centerIn: parent
                        text: utilModule.displayBrightness < 0.35 ? "󰃞" :
                              (utilModule.displayBrightness < 0.7 ? "󰃟" : "󰃠")
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                        color: (brightFillBar.width > 26) 
                               ? (Theme.colors.bg ?? "#12141c") 
                               : "white"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // Drag & Wheel Interaction Area
                MouseArea {
                    id: brightMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function updatePos(xVal) {
                        var ratio = Math.max(0.01, Math.min(1.0, xVal / brightTrack.width));
                        utilModule.setBrightness(ratio);
                    }

                    onPressed: (mouse) => {
                        utilModule.isDraggingBrightness = true;
                        updatePos(mouse.x);
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) updatePos(mouse.x);
                    }
                    onReleased: {
                        utilModule.isDraggingBrightness = false;
                    }
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        utilModule.setBrightness(utilModule.displayBrightness + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
                    }
                }
            }
        }

        // ===== ROW 5: QUICK UTILITIES (CLIPBOARD | NOTES | SHELF | KEYS | OCR) =====
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 5

            // Clipboard Pill
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 17
                color: clipMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰅍"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        color: utilModule.accentColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Clips"
                        font.pixelSize: 10; font.bold: true
                        color: Theme.colors.text_primary ?? "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: clipMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.switchMode("clipboard", true)
                }
            }

            // Notes & Tasks Pill
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 17
                color: notesMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰠮"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        color: "#bb9af7"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Notes"
                        font.pixelSize: 10; font.bold: true
                        color: Theme.colors.text_primary ?? "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: notesMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.switchMode("notes", true)
                }
            }

            // Shelf Pill
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 17
                color: shelfMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰪶"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        color: "#73daca"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Shelf"
                        font.pixelSize: 10; font.bold: true
                        color: Theme.colors.text_primary ?? "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: shelfMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.switchMode("shelf", true)
                }
            }

            // Keybinds Cheat Sheet Pill
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 17
                color: keysMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰌌"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        color: "#7dcfff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Keys"
                        font.pixelSize: 10; font.bold: true
                        color: Theme.colors.text_primary ?? "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: keysMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.switchMode("cheatsheet", true)
                }
            }

            // Screen OCR Pill
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 17
                color: ocrMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : utilModule.cardColor
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰈙"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        color: "#9ece6a"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "OCR"
                        font.pixelSize: 10; font.bold: true
                        color: Theme.colors.text_primary ?? "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: ocrMouse
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        root.collapseToIdle();
                        if (typeof dashMod !== "undefined") dashMod.startOcr();
                    }
                }
            }
        }
    }
}
