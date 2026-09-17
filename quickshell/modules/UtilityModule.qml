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
    // STATE PROPERTIES & CONTROLS
    // ========================================================
    property string activeSection: "" // "" (main), "audio"

    property bool nightLightActive: false
    property bool caffeineActive: false
    property bool audioMuted: false
    property real audioVolume: 0.5
    property bool audioMicMuted: false
    property real audioMicVolume: 0.5
    property real displayBrightness: 0.5

    property bool isDraggingVolume: false
    property bool isDraggingBrightness: false

    readonly property color colBg: "#000000"
    readonly property color colCard: "#161924"
    readonly property color colCardHover: "#202534"
    readonly property color colAccent: Theme.colors.accent ?? "#7aa2f7"
    readonly property color colText: Theme.colors.text_primary ?? "#eceff4"
    readonly property color colSubtext: Theme.colors.text_secondary ?? "#d8dee9"
    readonly property color colMuted: Theme.colors.text_muted ?? "#81a1c1"

    readonly property bool wifiEnabled: typeof wifiMod !== "undefined" ? wifiMod.wifiEnabled : true
    readonly property bool btEnabled: typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property string activeNetName: typeof dashMod !== "undefined" ? dashMod.activeNetName : ""
    readonly property string activeBtName: typeof dashMod !== "undefined" ? dashMod.btDeviceName : ""

    function forceNotesFocus() {}

    // 1. Night Light (hyprsunset)
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

    function toggleNightLight() {
        if (nightLightActive) {
            Quickshell.execDetached(["sh", "-c", "killall -9 hyprsunset 2>/dev/null"]);
            nightLightActive = false;
        } else {
            Quickshell.execDetached(["sh", "-c", "killall -9 hyprsunset 2>/dev/null; hyprsunset -t 4500"]);
            nightLightActive = true;
        }
        checkNightLight.running = true;
    }

    // 2. Caffeine (systemd-inhibit)
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

    // 3. Audio Volume & Mute (wpctl)
    Process {
        id: fetchVolumeProcess
        running: false
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = this.text.trim();
                utilModule.audioMuted = txt.includes("[MUTED]");
                var parts = txt.split(/\s+/);
                if (parts.length >= 2 && !utilModule.isDraggingVolume) {
                    var v = parseFloat(parts[1]);
                    if (!isNaN(v)) {
                        utilModule.audioVolume = Math.max(0.0, Math.min(1.0, v));
                    }
                }
            }
        }
    }

    Process {
        id: fetchMicProcess
        running: false
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = this.text.trim();
                utilModule.audioMicMuted = txt.includes("[MUTED]");
                var parts = txt.split(/\s+/);
                if (parts.length >= 2) {
                    var v = parseFloat(parts[1]);
                    if (!isNaN(v)) {
                        utilModule.audioMicVolume = Math.max(0.0, Math.min(1.0, v));
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

    function toggleMicMute() {
        utilModule.audioMicMuted = !utilModule.audioMicMuted;
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
        fetchMicProcess.running = true;
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
                    utilModule.displayBrightness = Math.max(0.01, Math.min(1.0, val / 100.0));
                }
            }
        }
    }

    function setBrightness(ratio) {
        var pct = Math.max(1, Math.min(100, Math.round(ratio * 100)));
        utilModule.displayBrightness = pct / 100.0;
        Quickshell.execDetached(["brightnessctl", "set", pct + "%"]);
    }

    // 5. Audio Devices Data (Sinks & Sources)
    property var audioSinks: []
    property var audioSources: []

    Process {
        id: fetchAudioDevices
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/my_own/scripts/audio_devices.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    utilModule.audioSinks = data.sinks || [];
                    utilModule.audioSources = data.sources || [];
                } catch (e) {}
            }
        }
    }

    function setDefaultSink(sinkName) {
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/quickshell/my_own/scripts/audio_devices.py", "set-sink", sinkName]);
        fetchAudioDevices.running = true;
        fetchVolumeProcess.running = true;
    }

    function setDefaultSource(sourceName) {
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/quickshell/my_own/scripts/audio_devices.py", "set-source", sourceName]);
        fetchAudioDevices.running = true;
        fetchMicProcess.running = true;
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            checkNightLight.running = true;
            fetchVolumeProcess.running = true;
            fetchMicProcess.running = true;
            fetchBrightnessProcess.running = true;
            if (utilModule.activeSection === "audio") fetchAudioDevices.running = true;
        }
    }

    // ========================================================
    // ========================================================
    // REUSABLE ANDROID 17 MATERIAL 3 EXPRESSIVE COMPONENTS
    // ========================================================

    // 1. Inir Style Tactile Circular Button (with label underneath, solid 3D depth, no border)
    component InirRoundBtn: Item {
        id: btn
        property string glyph: ""
        property string label: ""
        property bool lit: false
        property color tint: utilModule.colAccent
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 70

        scale: btnMouse.pressed ? 0.92 : (btnMouse.containsMouse ? 1.035 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

        Column {
            anchors.centerIn: parent
            spacing: 5
            width: parent.width

            // Solid 3D Circular Button (no border)
            Rectangle {
                id: circleBg
                width: 48
                height: 48
                radius: 24
                anchors.horizontalCenter: parent.horizontalCenter
                color: btn.lit ? (btn.tint || utilModule.colAccent) : (btnMouse.containsMouse ? "#262b3d" : "#171a27")
                border.width: 0
                Behavior on color { ColorAnimation { duration: 130 } }

                // Bottom 3D shadow rim
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 32
                    height: 2.5
                    radius: 1.25
                    color: btn.lit ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(0, 0, 0, 0.45)
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: btn.glyph
                    fill: btn.lit ? 1 : 0
                    iconSize: 22
                    color: btn.lit ? "#09101d" : "#e2e8f0"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            // Text Label Underneath
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: btn.label
                font.family: "Noto Sans"
                font.pixelSize: 11
                font.weight: btn.lit ? Font.Bold : Font.Medium
                color: btn.lit ? "#f1f5f9" : "#94a3b8"
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // 2. Android 16/17 Sleek Slim Capsule Slider (32px height, no border, unified accent)
    component AndroidHorizontalSlider: Rectangle {
        id: slider
        property real value: 0.5
        property string icon: "volume_up"
        property string percentText: "50%"
        property bool muted: false
        property color activeColor: utilModule.colAccent
        signal moved(real val)
        signal iconClicked()

        property real dragVal: -1
        readonly property real currentRatio: Math.max(0.0, Math.min(1.0, slider.dragVal >= 0 ? slider.dragVal : slider.value))

        Layout.fillWidth: true
        implicitHeight: 32
        radius: 16

        color: "#141722"
        border.width: 0

        scale: sliderMouse.pressed ? 0.99 : (sliderMouse.containsMouse ? 1.008 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90 } }

        // Bottom 3D shadow rim
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 2
            radius: 1
            color: Qt.rgba(0, 0, 0, 0.4)
        }

        // Dynamic Fill Track
        Item {
            id: fillClip
            anchors.fill: parent
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: (slider.muted || slider.currentRatio <= 0.001) ? 0 : Math.max(slider.height, slider.height + (parent.width - slider.height) * slider.currentRatio)
                radius: slider.radius
                color: slider.muted ? Qt.rgba(255, 255, 255, 0.1) : slider.activeColor

                Behavior on width {
                    enabled: slider.dragVal < 0
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }

                // 3D Right Highlight Meniscus on leading edge
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: 2.5
                    radius: 1.25
                    color: Qt.rgba(255, 255, 255, 0.35)
                    visible: slider.currentRatio > 0.04 && !slider.muted
                }
            }
        }

        // Left Icon Container (Dedicated circle matching capsule height)
        Item {
            id: iconArea
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: slider.height
            height: slider.height
            z: 5

            MaterialSymbol {
                anchors.centerIn: parent
                text: slider.icon
                fill: 1
                iconSize: 18
                color: slider.muted ? "#f87171" : (slider.currentRatio > 0.001 ? "#09101d" : "#94a3b8")
                Behavior on color { ColorAnimation { duration: 90 } }
            }
        }

        // Right Percentage Label
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            z: 5
            text: slider.percentText
            font.family: "Noto Sans"
            font.pixelSize: 11
            font.weight: Font.Bold
            color: slider.muted ? "#f87171" : (slider.currentRatio > 0.85 ? "#09101d" : "#ffffff")
            Behavior on color { ColorAnimation { duration: 90 } }
        }

        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function calcRatio(mouseX) {
                if (mouseX <= 16) return 0.0;
                if (mouseX >= width - 16) return 1.0;
                return (mouseX - 16) / (width - 32);
            }

            onPressed: (mouse) => {
                if (mouse.x <= 32) {
                    slider.iconClicked();
                    return;
                }
                slider.dragVal = calcRatio(mouse.x);
                slider.moved(slider.dragVal);
            }

            onPositionChanged: (mouse) => {
                if (!pressed || slider.dragVal < 0) return;
                slider.dragVal = calcRatio(mouse.x);
                slider.moved(slider.dragVal);
            }

            onReleased: {
                slider.dragVal = -1;
                utilModule.isDraggingBrightness = false;
                utilModule.isDraggingVolume = false;
            }
        }
    }

    // 3. Compact 3D Header Quick Action Button (solid, no border, tactile depth)
    component HeaderQuickBtn: Rectangle {
        id: hbtn
        property string glyph: ""
        property color iconColor: "#e2e8f0"
        property color customBg: "#1a1d2b"
        property color hoverBg: "#252b3d"
        signal clicked()

        width: 28
        height: 28
        radius: 8
        color: hmouse.containsMouse ? hbtn.hoverBg : hbtn.customBg
        border.width: 0

        scale: hmouse.pressed ? 0.90 : (hmouse.containsMouse ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 110 } }

        // Bottom 3D shadow rim
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 6
            height: 2
            radius: 1
            color: Qt.rgba(0, 0, 0, 0.4)
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: hbtn.glyph
            iconSize: 15
            color: hbtn.iconColor
        }

        MouseArea {
            id: hmouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: hbtn.clicked()
        }
    }

    // ========================================================
    // MAIN LAYOUT
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        // ── TOP HEADER BAR ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Tactile Action Icon or Back Button
            Rectangle {
                width: 28; height: 28; radius: 8
                color: headerBackMouse.containsMouse ? "#252b3d" : "#1a1d2b"
                border.width: 0
                scale: headerBackMouse.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 6
                    height: 2
                    radius: 1
                    color: Qt.rgba(0, 0, 0, 0.4)
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: utilModule.activeSection !== "" ? "arrow_back" : "tune"
                    iconSize: 15
                    color: utilModule.activeSection !== "" ? utilModule.colAccent : "#e2e8f0"
                }

                MouseArea {
                    id: headerBackMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (utilModule.activeSection !== "") {
                            utilModule.activeSection = "";
                        } else {
                            root.collapseToIdle();
                        }
                    }
                }
            }

            // Title & Date Pill
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: utilModule.activeSection === "audio" ? "Sound Devices" : "Control Center"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: "#f1f5f9"
                }

                Text {
                    text: utilModule.activeSection !== "" ? "Select preferred output & input" : Qt.formatDate(clock.date, "dddd, d MMMM")
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    color: "#94a3b8"
                }
            }

            // Quick Shortcut Badges (Drop files, OCR, Notes, Clipboard, Theme, Lock, Power)
            RowLayout {
                spacing: 5
                visible: utilModule.activeSection === ""

                // 1. Drop files / Shelf
                HeaderQuickBtn {
                    glyph: "inventory_2"
                    onClicked: root.switchMode("shelf", false)
                }

                // 2. OCR Snip
                HeaderQuickBtn {
                    glyph: "document_scanner"
                    onClicked: {
                        root.collapseToIdle();
                        Quickshell.execDetached(["/bin/sh", "-c", "$HOME/.config/quickshell/my_own/scripts/snip_ocr.sh"]);
                    }
                }

                // 3. Notes
                HeaderQuickBtn {
                    glyph: "edit_note"
                    onClicked: root.switchMode("notes", false)
                }

                // 4. Clipboard History
                HeaderQuickBtn {
                    glyph: "assignment"
                    onClicked: root.switchMode("clipboard", false)
                }

                // 5. Theme Selector
                HeaderQuickBtn {
                    glyph: "palette"
                    onClicked: root.switchMode("theme", false)
                }

                // 6. Lock Screen
                HeaderQuickBtn {
                    glyph: "lock"
                    onClicked: {
                        root.collapseToIdle();
                        Quickshell.execDetached(["hyprlock"]);
                    }
                }

                // 7. Power Menu
                HeaderQuickBtn {
                    glyph: "power_settings_new"
                    iconColor: "#ff5555"
                    customBg: Qt.rgba(255, 85, 85, 0.12)
                    hoverBg: Qt.rgba(255, 85, 85, 0.25)
                    onClicked: root.switchMode("powermenu", false)
                }
            }
        }

        // ── 1. MAIN CONTROL CENTER VIEW ────────────────────────────
        ColumnLayout {
            id: mainViewContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            visible: utilModule.activeSection === ""

            // 1. TWO 2x2 GRIDS SIDE-BY-SIDE (Inir Style: Circular Icon + Label Underneath)
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // LEFT 2x2: Connectivity & Audio (Wi-Fi, Bluetooth, Focus, Mic)
                GridLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8

                    // Wi-Fi
                    InirRoundBtn {
                        glyph: (typeof dashMod !== "undefined" && dashMod.activeNetType === "eth") ? "lan" : (utilModule.wifiEnabled ? "wifi" : "wifi_off")
                        label: (typeof dashMod !== "undefined" && dashMod.activeNetType === "eth") ? "Ethernet" : (utilModule.activeNetName !== "" ? utilModule.activeNetName : (utilModule.wifiEnabled ? "Wi-Fi" : "Off"))
                        lit: utilModule.wifiEnabled
                        onClicked: root.switchMode("wifi", false)
                    }

                    // Bluetooth
                    InirRoundBtn {
                        glyph: utilModule.btEnabled ? "bluetooth" : "bluetooth_disabled"
                        label: utilModule.activeBtName !== "" ? utilModule.activeBtName : "Bluetooth"
                        lit: utilModule.btEnabled
                        onClicked: root.switchMode("bluetooth", false)
                    }

                    // Focus Mode (DND)
                    InirRoundBtn {
                        glyph: root.dndEnabled ? "do_not_disturb_on" : "do_not_disturb_off"
                        label: "Focus"
                        lit: root.dndEnabled
                        onClicked: root.dndEnabled = !root.dndEnabled
                    }

                    // Microphone
                    InirRoundBtn {
                        glyph: utilModule.audioMicMuted ? "mic_off" : "mic"
                        label: utilModule.audioMicMuted ? "Muted" : "Mic"
                        lit: !utilModule.audioMicMuted
                        onClicked: utilModule.toggleMicMute()
                    }
                }

                // RIGHT 2x2: Quick Utilities (Capture, Record, Devices, Caffeine)
                GridLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8

                    // Capture
                    InirRoundBtn {
                        glyph: "crop"
                        label: "Capture"
                        lit: false
                        onClicked: {
                            root.collapseToIdle();
                            Quickshell.execDetached(["sh", "-c", 'F="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y%m%d_%H%M%S).png"; mkdir -p "$(dirname "$F")"; grim -g "$(slurp)" "$F" && wl-copy < "$F" && notify-send "Screenshot" "Area copied to clipboard and saved"']);
                        }
                    }

                    // Record
                    InirRoundBtn {
                        glyph: (typeof recMod !== "undefined" && recMod.isRecording) ? "stop_circle" : "radio_button_checked"
                        label: (typeof recMod !== "undefined" && recMod.isRecording) ? "Recording" : "Record"
                        lit: typeof recMod !== "undefined" && recMod.isRecording
                        tint: "#f87171"
                        onClicked: root.switchMode("recorder", false)
                    }

                    // Devices
                    InirRoundBtn {
                        glyph: "headphones"
                        label: "Devices"
                        lit: utilModule.activeSection === "audio"
                        onClicked: {
                            utilModule.activeSection = "audio";
                            fetchAudioDevices.running = true;
                        }
                    }

                    // Caffeine
                    InirRoundBtn {
                        glyph: "coffee"
                        label: "Caffeine"
                        lit: utilModule.caffeineActive
                        onClicked: utilModule.toggleCaffeine()
                    }
                }
            }

            // 2. SLEEK HORIZONTAL SLIDERS (Brightness & Volume, 32px height)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // Brightness Slider
                AndroidHorizontalSlider {
                    value: utilModule.displayBrightness
                    icon: "light_mode"
                    percentText: Math.round(utilModule.displayBrightness * 100) + "%"
                    activeColor: utilModule.colAccent
                    onMoved: (val) => {
                        utilModule.isDraggingBrightness = true;
                        utilModule.setBrightness(val);
                    }
                    onIconClicked: utilModule.setBrightness(utilModule.displayBrightness > 0.5 ? 0.2 : 0.8)
                }

                // Volume Slider
                AndroidHorizontalSlider {
                    value: utilModule.audioVolume
                    icon: utilModule.audioMuted ? "volume_off" : (utilModule.audioVolume > 0.5 ? "volume_up" : (utilModule.audioVolume > 0 ? "volume_down" : "volume_mute"))
                    percentText: utilModule.audioMuted ? "Muted" : (Math.round(utilModule.audioVolume * 100) + "%")
                    muted: utilModule.audioMuted
                    activeColor: utilModule.colAccent
                    onMoved: (val) => {
                        utilModule.isDraggingVolume = true;
                        utilModule.setVolume(val);
                    }
                    onIconClicked: utilModule.toggleMute()
                }
            }
        }

        // ── 2. SOUND DEVICES SUBVIEW ───────────────────────────────
        ColumnLayout {
            id: audioSubviewContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            visible: utilModule.activeSection === "audio"

            Text {
                text: "OUTPUT AUDIO SINKS"
                font.family: "Noto Sans"
                font.pixelSize: 11
                font.weight: Font.Bold
                color: utilModule.colMuted
            }

            Repeater {
                model: utilModule.audioSinks
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: 14
                    color: modelData.isDefault ? Qt.rgba(utilModule.colAccent.r, utilModule.colAccent.g, utilModule.colAccent.b, 0.22) : (sinkMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
                    border.width: 1
                    border.color: modelData.isDefault ? utilModule.colAccent : Qt.rgba(1, 1, 1, 0.08)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 10

                        MaterialSymbol {
                            text: modelData.name.includes("bluez") ? "headphones" : "speaker"
                            iconSize: 20
                            color: modelData.isDefault ? utilModule.colAccent : utilModule.colText
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.desc || modelData.name
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                            font.weight: modelData.isDefault ? Font.DemiBold : Font.Normal
                            color: modelData.isDefault ? utilModule.colAccent : utilModule.colText
                            elide: Text.ElideRight
                        }

                        MaterialSymbol {
                            visible: modelData.isDefault
                            text: "check_circle"
                            iconSize: 18
                            color: utilModule.colAccent
                        }
                    }

                    MouseArea {
                        id: sinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: utilModule.setDefaultSink(modelData.name)
                    }
                }
            }

            Item { Layout.preferredHeight: 4 }

            Text {
                text: "INPUT MICROPHONE SOURCES"
                font.family: "Noto Sans"
                font.pixelSize: 11
                font.weight: Font.Bold
                color: utilModule.colMuted
            }

            Repeater {
                model: utilModule.audioSources
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: 14
                    color: modelData.isDefault ? Qt.rgba(utilModule.colAccent.r, utilModule.colAccent.g, utilModule.colAccent.b, 0.22) : (sourceMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
                    border.width: 1
                    border.color: modelData.isDefault ? utilModule.colAccent : Qt.rgba(1, 1, 1, 0.08)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 10

                        MaterialSymbol {
                            text: "mic"
                            iconSize: 20
                            color: modelData.isDefault ? utilModule.colAccent : utilModule.colText
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.desc || modelData.name
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                            font.weight: modelData.isDefault ? Font.DemiBold : Font.Normal
                            color: modelData.isDefault ? utilModule.colAccent : utilModule.colText
                            elide: Text.ElideRight
                        }

                        MaterialSymbol {
                            visible: modelData.isDefault
                            text: "check_circle"
                            iconSize: 18
                            color: utilModule.colAccent
                        }
                    }

                    MouseArea {
                        id: sourceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: utilModule.setDefaultSource(modelData.name)
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
