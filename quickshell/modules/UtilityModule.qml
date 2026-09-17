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
    readonly property color colCard: Theme.colors.card_bg ?? "#161924"
    readonly property color colCardHover: Theme.colors.hover_bg ?? "#202534"
    readonly property color colAccent: Theme.colors.accent ?? "#7aa2f7"
    readonly property color colText: Theme.colors.text_primary ?? "#eceff4"
    readonly property color colSubtext: Theme.colors.text_secondary ?? "#d8dee9"
    readonly property color colMuted: Theme.colors.text_muted ?? "#81a1c1"

    // Reactive Connectivity Data
    readonly property bool wifiEnabled: typeof wifiMod !== "undefined" ? wifiMod.wifiEnabled : true
    readonly property bool btEnabled: typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property string activeNetName: typeof dashMod !== "undefined" ? dashMod.activeNetName : ""
    readonly property string activeNetType: typeof dashMod !== "undefined" ? dashMod.activeNetType : "wifi"
    readonly property int activeNetSignal: typeof dashMod !== "undefined" ? dashMod.activeNetSignal : 0
    readonly property string activeBtName: typeof dashMod !== "undefined" ? dashMod.btDeviceName : ""
    readonly property string activeBtBattery: typeof dashMod !== "undefined" ? dashMod.btIslandBattery : ""

    function forceNotesFocus() {}

    // ========================================================
    // HARDWARE ACTIONS & PROCESSES
    // ========================================================

    // 1. Wi-Fi Toggle & Open
    function toggleWifi() {
        var willEnable = !utilModule.wifiEnabled;
        if (typeof wifiMod !== "undefined") {
            wifiMod.wifiEnabled = willEnable;
        }
        Quickshell.execDetached(["nmcli", "radio", "wifi", willEnable ? "on" : "off"]);
        if (typeof wifiMod !== "undefined") {
            wifiMod.refreshStatus();
        }
    }

    // 2. Bluetooth Toggle & Open
    function toggleBluetooth() {
        if (typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
        } else {
            Quickshell.execDetached(["rfkill", "toggle", "bluetooth"]);
        }
    }

    // 3. Night Light (hyprsunset)
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

    // 4. Caffeine (systemd-inhibit)
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

    // 5. Screen OCR
    function triggerOcr() {
        root.collapseToIdle();
        Quickshell.execDetached(["/bin/sh", "-c", Qt.resolvedUrl("../scripts/snip_ocr.sh").toString().replace("file://", "")]);
    }

    // 6. Color Picker (hyprpicker)
    function triggerColorPicker() {
        root.collapseToIdle();
        Quickshell.execDetached(["sh", "-c", "sleep 0.15; hyprpicker -a && notify-send 'Color Picker' \"Copied $(wl-paste) to clipboard\""]);
    }

    // 7. Area Screenshot (grim + slurp)
    function triggerScreenshot() {
        root.collapseToIdle();
        Quickshell.execDetached(["sh", "-c", 'sleep 0.15; F="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y%m%d_%H%M%S).png"; mkdir -p "$(dirname "$F")"; grim -g "$(slurp)" "$F" && wl-copy < "$F" && notify-send "Screenshot" "Area copied to clipboard and saved"']);
    }

    // 8. Audio Volume & Mute (wpctl)
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

    // 9. Display Brightness (brightnessctl)
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

    // 10. Audio Devices Data (Sinks & Sources)
    property var audioSinks: []
    property var audioSources: []

    Process {
        id: fetchAudioDevices
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", "")]
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
        Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", ""), "set-sink", sinkName]);
        fetchAudioDevices.running = true;
        fetchVolumeProcess.running = true;
    }

    function setDefaultSource(sourceName) {
        Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", ""), "set-source", sourceName]);
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
    // REUSABLE MODERN BENTO GRID COMPONENTS
    // ========================================================

    // 1. Bento Split Pill for Wi-Fi & Bluetooth (Left: Toggle on/off | Right: Open section)
    component BentoSplitPill: Rectangle {
        id: pill
        property string glyph: ""
        property string title: ""
        property string subtitle: ""
        property bool isActive: false
        property color activeColor: utilModule.colAccent
        signal toggleClicked()
        signal detailClicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 56
        radius: 16

        color: pill.isActive ? Qt.rgba(pill.activeColor.r, pill.activeColor.g, pill.activeColor.b, 0.12) : "#141723"
        border.width: 1
        border.color: pill.isActive ? Qt.rgba(pill.activeColor.r, pill.activeColor.g, pill.activeColor.b, 0.32) : Qt.rgba(255, 255, 255, 0.06)

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 6

            // Left: Circular Toggle Button (Turns Radio ON / OFF)
            Item {
                width: 44
                height: 44

                Rectangle {
                    id: toggleRect
                    anchors.centerIn: parent
                    width: 44
                    height: 44
                    radius: 13
                    color: pill.isActive ? pill.activeColor : (toggleMouse.containsMouse ? "#262b3c" : "#1b1f2e")
                    border.width: 1
                    border.color: pill.isActive ? Qt.rgba(255, 255, 255, 0.2) : (toggleMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.04))

                    scale: toggleMouse.pressed ? 0.90 : (toggleMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: pill.glyph
                        fill: pill.isActive ? 1 : 0
                        iconSize: 21
                        color: pill.isActive ? "#09101d" : "#94a3b8"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: toggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.toggleClicked()
                    }
                }
            }

            // Divider Line
            Rectangle {
                width: 1
                height: 24
                radius: 0.5
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            // Right: Detail Area (Opens Main Wi-Fi / Bluetooth Module)
            Rectangle {
                id: detailArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 11
                color: detailMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                scale: detailMouse.pressed ? 0.98 : 1.0
                Behavior on scale { NumberAnimation { duration: 80 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 8
                    spacing: 4

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: pill.title
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: pill.isActive ? "#f8fafc" : "#cbd5e1"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: pill.subtitle
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            font.weight: Font.Normal
                            color: pill.isActive ? pill.activeColor : "#64748b"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    MaterialSymbol {
                        text: "chevron_right"
                        iconSize: 16
                        color: detailMouse.containsMouse ? "#ffffff" : (pill.isActive ? "#94a3b8" : "#475569")
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }
                }

                MouseArea {
                    id: detailMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.detailClicked()
                }
            }
        }
    }

    // 2. Bento Quick Action Squircle Button (Grid Toggle with centered label underneath)
    component BentoQuickBtn: Item {
        id: btn
        property string glyph: ""
        property string label: ""
        property bool lit: false
        property color tint: utilModule.colAccent
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 58

        Column {
            anchors.centerIn: parent
            spacing: 4
            width: parent.width

            // Tactile Squircle Icon Card
            Rectangle {
                id: squircleBg
                width: 42
                height: 42
                radius: 13
                anchors.horizontalCenter: parent.horizontalCenter
                color: btn.lit ? (btn.tint || utilModule.colAccent) : (btnMouse.containsMouse ? "#24293c" : "#161926")
                border.width: 1
                border.color: btn.lit ? Qt.rgba(btn.tint.r, btn.tint.g, btn.tint.b, 0.4) : (btnMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : Qt.rgba(255, 255, 255, 0.04))

                scale: btnMouse.pressed ? 0.90 : (btnMouse.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: btn.glyph
                    fill: btn.lit ? 1 : 0
                    iconSize: 20
                    color: btn.lit ? "#09101d" : (btnMouse.containsMouse ? "#f8fafc" : "#94a3b8")
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
                font.pixelSize: 10
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

    // 3. Android 16/17 Sleek Slim Capsule Slider (34px height, integrated icon, mouse wheel support)
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
        implicitHeight: 34
        radius: 17

        color: "#141724"
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.05)

        scale: sliderMouse.pressed ? 0.985 : (sliderMouse.containsMouse ? 1.006 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90 } }

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
            }
        }

        // Left Icon Container
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
            color: slider.muted ? "#f87171" : (slider.currentRatio > 0.94 ? "#09101d" : "#ffffff")
            style: Text.Outline
            styleColor: slider.currentRatio > 0.94 ? "transparent" : Qt.rgba(0, 0, 0, 0.45)
            Behavior on color { ColorAnimation { duration: 90 } }
        }

        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function calcRatio(mouseX) {
                if (mouseX <= 17) return 0.0;
                if (mouseX >= width - 17) return 1.0;
                return (mouseX - 17) / (width - 34);
            }

            onPressed: (mouse) => {
                if (mouse.x <= 34) {
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

            onWheel: (wheel) => {
                var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                slider.moved(Math.max(0.0, Math.min(1.0, slider.currentRatio + step)));
            }
        }
    }

    // 4. Compact 3D Header Quick Action Button
    component HeaderQuickBtn: Rectangle {
        id: hbtn
        property string glyph: ""
        property color iconColor: "#e2e8f0"
        property color customBg: "#181b28"
        property color hoverBg: "#252b3d"
        signal clicked()

        width: 28
        height: 28
        radius: 8
        color: hmouse.containsMouse ? hbtn.hoverBg : hbtn.customBg
        border.width: 1
        border.color: hmouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : Qt.rgba(255, 255, 255, 0.04)

        scale: hmouse.pressed ? 0.90 : (hmouse.containsMouse ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 110 } }

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

            // Tactile Back / Exit Button
            Rectangle {
                width: 28; height: 28; radius: 8
                color: headerBackMouse.containsMouse ? "#252b3d" : "#181b28"
                border.width: 1
                border.color: headerBackMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : Qt.rgba(255, 255, 255, 0.04)
                scale: headerBackMouse.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

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

            // Title & Date Subtitle
            ColumnLayout {
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
                    font.pixelSize: 10
                    color: "#94a3b8"
                }
            }

            Item { Layout.fillWidth: true }

            // Quick Shortcut Badges (Shelf, OCR, Notes, Clipboard, Theme, Lock, Power)
            RowLayout {
                spacing: 5
                Layout.alignment: Qt.AlignRight
                visible: utilModule.activeSection === ""

                // 1. Drop files / Shelf
                HeaderQuickBtn {
                    glyph: "inventory_2"
                    onClicked: root.switchMode("shelf", false)
                }

                // 2. OCR Snip
                HeaderQuickBtn {
                    glyph: "document_scanner"
                    onClicked: utilModule.triggerOcr()
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

        // ── 1. MAIN CONTROL CENTER VIEW (MODERN BENTO GRID) ────────
        ColumnLayout {
            id: mainViewContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 9
            visible: utilModule.activeSection === ""

            // 1. HERO BENTO SPLIT PILLS: Wi-Fi & Bluetooth
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Wi-Fi Split Pill
                BentoSplitPill {
                    glyph: (utilModule.activeNetType === "eth") ? "lan" : (utilModule.wifiEnabled ? "wifi" : "wifi_off")
                    title: (utilModule.activeNetType === "eth") ? "Ethernet" : (utilModule.wifiEnabled ? (utilModule.activeNetName !== "" ? utilModule.activeNetName : "Wi-Fi") : "Wi-Fi")
                    subtitle: {
                        if (utilModule.activeNetType === "eth") return "Connected • Wired";
                        if (!utilModule.wifiEnabled) return "Disabled • Tap to turn on";
                        if (utilModule.activeNetName !== "") {
                            return utilModule.activeNetSignal > 0 ? ("Connected • " + utilModule.activeNetSignal + "%") : "Connected";
                        }
                        return "Disconnected • Search";
                    }
                    isActive: utilModule.wifiEnabled
                    onToggleClicked: utilModule.toggleWifi()
                    onDetailClicked: root.switchMode("wifi", false)
                }

                // Bluetooth Split Pill
                BentoSplitPill {
                    glyph: utilModule.btEnabled ? "bluetooth" : "bluetooth_disabled"
                    title: utilModule.btEnabled ? (utilModule.activeBtName !== "" ? utilModule.activeBtName : "Bluetooth") : "Bluetooth"
                    subtitle: {
                        if (!utilModule.btEnabled) return "Disabled • Tap to turn on";
                        if (utilModule.activeBtName !== "") {
                            return utilModule.activeBtBattery !== "" ? ("Connected • " + utilModule.activeBtBattery) : "Connected";
                        }
                        return "Ready to pair";
                    }
                    isActive: utilModule.btEnabled
                    onToggleClicked: utilModule.toggleBluetooth()
                    onDetailClicked: root.switchMode("bluetooth", false)
                }
            }

            // 2. SECONDARY 4x2 BENTO QUICK TOGGLES GRID
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 6
                columnSpacing: 8

                // Row 1:
                // 1. Night Light (hyprsunset)
                BentoQuickBtn {
                    glyph: "nightlight"
                    label: "Night Light"
                    lit: utilModule.nightLightActive
                    tint: "#f59e0b"
                    onClicked: utilModule.toggleNightLight()
                }

                // 2. Color Picker (hyprpicker)
                BentoQuickBtn {
                    glyph: "colorize"
                    label: "Picker"
                    lit: false
                    tint: "#7dcfff"
                    onClicked: utilModule.triggerColorPicker()
                }

                // 3. Focus Mode / DND
                BentoQuickBtn {
                    glyph: root.dndEnabled ? "do_not_disturb_on" : "do_not_disturb_off"
                    label: "Focus"
                    lit: root.dndEnabled
                    tint: "#bb9af7"
                    onClicked: root.dndEnabled = !root.dndEnabled
                }

                // 4. Caffeine (idle sleep inhibitor)
                BentoQuickBtn {
                    glyph: "coffee"
                    label: "Caffeine"
                    lit: utilModule.caffeineActive
                    tint: "#ff9e64"
                    onClicked: utilModule.toggleCaffeine()
                }

                // Row 2:
                // 5. Screenshot Capture (grim + slurp)
                BentoQuickBtn {
                    glyph: "crop"
                    label: "Capture"
                    lit: false
                    tint: "#2ac3de"
                    onClicked: utilModule.triggerScreenshot()
                }

                // 6. Screen Recorder
                BentoQuickBtn {
                    glyph: (typeof recMod !== "undefined" && recMod.isRecording) ? "stop_circle" : "radio_button_checked"
                    label: (typeof recMod !== "undefined" && recMod.isRecording) ? "Recording" : "Record"
                    lit: typeof recMod !== "undefined" && recMod.isRecording
                    tint: "#f7768e"
                    onClicked: root.switchMode("recorder", false)
                }

                // 7. Sound Devices Switcher
                BentoQuickBtn {
                    glyph: "headphones"
                    label: "Devices"
                    lit: utilModule.activeSection === "audio"
                    tint: utilModule.colAccent
                    onClicked: {
                        utilModule.activeSection = "audio";
                        fetchAudioDevices.running = true;
                    }
                }

                // 8. Microphone Mute
                BentoQuickBtn {
                    glyph: utilModule.audioMicMuted ? "mic_off" : "mic"
                    label: utilModule.audioMicMuted ? "Muted" : "Mic"
                    lit: !utilModule.audioMicMuted
                    tint: utilModule.audioMicMuted ? "#f7768e" : utilModule.colAccent
                    onClicked: utilModule.toggleMicMute()
                }
            }

            // 3. SLEEK HORIZONTAL CAPSULE SLIDERS (Brightness & Volume)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

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
                    color: modelData.isDefault ? Qt.rgba(utilModule.colAccent.r, utilModule.colAccent.g, utilModule.colAccent.b, 0.20) : (sinkMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
                    border.width: 1
                    border.color: modelData.isDefault ? utilModule.colAccent : Qt.rgba(255, 255, 255, 0.06)

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
                    color: modelData.isDefault ? Qt.rgba(utilModule.colAccent.r, utilModule.colAccent.g, utilModule.colAccent.b, 0.20) : (sourceMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
                    border.width: 1
                    border.color: modelData.isDefault ? utilModule.colAccent : Qt.rgba(255, 255, 255, 0.06)

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
