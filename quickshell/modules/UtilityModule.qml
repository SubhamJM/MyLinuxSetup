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
    property bool wifiEnabled: true
    property bool isTogglingWifi: false
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

    // 1. Wi-Fi Toggle & Monitoring
    Process {
        id: checkWifiRadio
        running: true
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (utilModule.isTogglingWifi) return;
                var isEnabled = this.text.trim() === "enabled";
                utilModule.wifiEnabled = isEnabled;
                if (typeof wifiMod !== "undefined") wifiMod.wifiEnabled = isEnabled;
            }
        }
    }

    Timer {
        id: wifiSettleTimer
        interval: 1000
        repeat: false
        onTriggered: {
            utilModule.isTogglingWifi = false;
            checkWifiRadio.running = true;
            if (typeof wifiMod !== "undefined") wifiMod.refreshStatus();
        }
    }

    function toggleWifi() {
        var targetState = !utilModule.wifiEnabled;
        utilModule.isTogglingWifi = true;
        utilModule.wifiEnabled = targetState;
        if (typeof wifiMod !== "undefined") {
            wifiMod.wifiEnabled = targetState;
        }
        Quickshell.execDetached(["nmcli", "radio", "wifi", targetState ? "on" : "off"]);
        wifiSettleTimer.restart();
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
        if (v > 0.001) {
            utilModule.audioMuted = false;
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
        } else {
            utilModule.audioMuted = true;
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1"]);
        }
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)]);
    }

    function toggleMute() {
        var willMute = !utilModule.audioMuted;
        utilModule.audioMuted = willMute;
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", willMute ? "1" : "0"]);
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
            checkWifiRadio.running = true;
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

    // ========================================================
    // REUSABLE MATERIAL YOU COMPONENTS
    // ========================================================

    // 1. Material You Pill Toggle (Wi-Fi, Bluetooth, Focus, Night Light)
    component MaterialPill: Rectangle {
        id: pill
        property string glyph: ""
        property string title: ""
        property string subtitle: ""
        property bool isActive: false
        property bool isSplit: false // If true, left circle toggles on/off, body opens detail
        property color activeColor: utilModule.colAccent
        signal toggleClicked()
        signal detailClicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 44
        radius: 22

        color: pill.isActive ? Qt.rgba(pill.activeColor.r, pill.activeColor.g, pill.activeColor.b, 0.22) : (discMouse.containsMouse || pillBodyMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.05)

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 10
            spacing: 8

            // Left: Circular Icon Disc
            Rectangle {
                id: discRect
                width: 36
                height: 36
                radius: 18
                color: pill.isActive ? pill.activeColor : (discMouse.containsMouse ? utilModule.colCardHover : "#202534")

                scale: discMouse.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: pill.glyph
                    fill: pill.isActive ? 1 : 0
                    iconSize: 19
                    color: pill.isActive ? "#0b0f19" : utilModule.colText
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: discMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.toggleClicked()
                }
            }

            // Right: Text Content Area
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Layout.alignment: Qt.AlignVCenter

                Text {
                    Layout.fillWidth: true
                    text: pill.title
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: pill.isActive ? "#ffffff" : utilModule.colText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: pill.subtitle
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.Normal
                    color: pill.isActive ? pill.activeColor : utilModule.colMuted
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        MouseArea {
            id: pillBodyMouse
            anchors.fill: parent
            anchors.leftMargin: 42
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (pill.isSplit) {
                    pill.detailClicked();
                } else {
                    pill.toggleClicked();
                }
            }
        }
    }

    // 2. Material You Circular Action Button (Lock, Power, etc.)
    component MaterialCircleBtn: Rectangle {
        id: cbtn
        property string glyph: ""
        property color iconColor: utilModule.colText
        property color customBg: utilModule.colCard
        property color hoverBg: utilModule.colCardHover
        signal clicked()

        implicitWidth: 44
        implicitHeight: 44
        radius: 22
        color: cmouse.containsMouse ? cbtn.hoverBg : cbtn.customBg
        border.width: 1
        border.color: cmouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : Qt.rgba(255, 255, 255, 0.05)

        scale: cmouse.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 110 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: cbtn.glyph
            iconSize: 19
            color: cbtn.iconColor
        }

        MouseArea {
            id: cmouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: cbtn.clicked()
        }
    }

    // 3. Material You Capsule Slider (integrated icon, dynamic fill, percentage & chevron)
    component MaterialSliderCard: Rectangle {
        id: scard
        property string title: ""
        property real value: 0.5
        property string icon: "volume_up"
        property string percentText: "50%"
        property bool muted: false
        property bool showChevron: false
        property color activeColor: utilModule.colAccent
        signal moved(real val)
        signal iconClicked()
        signal headerClicked()

        property real dragVal: -1
        readonly property real currentRatio: Math.max(0.0, Math.min(1.0, scard.dragVal >= 0 ? scard.dragVal : scard.value))

        Layout.fillWidth: true
        implicitHeight: 44
        radius: 22
        color: utilModule.colCard
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.05)

        scale: scardMouse.pressed ? 0.985 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }

        // Dynamic Fill Track
        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: (scard.muted || scard.currentRatio <= 0.001) ? 0 : Math.max(parent.height, parent.height + (parent.width - parent.height) * scard.currentRatio)
                radius: scard.radius
                color: scard.muted ? Qt.rgba(255, 255, 255, 0.1) : scard.activeColor

                Behavior on width {
                    enabled: scard.dragVal < 0
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }
            }
        }

        // Left Icon Container
        Item {
            id: iconArea
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: scard.height
            height: scard.height
            z: 5

            MaterialSymbol {
                anchors.centerIn: parent
                text: scard.icon
                fill: 1
                iconSize: 19
                color: scard.muted ? "#f87171" : (scard.currentRatio > 0.08 ? "#09101d" : utilModule.colText)
                Behavior on color { ColorAnimation { duration: 90 } }
            }
        }

        // Right Percentage Label + Optional Chevron
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            z: 5

            Text {
                text: scard.percentText
                font.family: "Noto Sans"
                font.pixelSize: 11
                font.weight: Font.Bold
                color: scard.muted ? "#f87171" : (scard.currentRatio > 0.88 ? "#09101d" : "#ffffff")
                Behavior on color { ColorAnimation { duration: 90 } }
            }

            MaterialSymbol {
                visible: scard.showChevron
                text: "chevron_right"
                iconSize: 17
                color: chevronMouse.containsMouse ? "#ffffff" : (scard.currentRatio > 0.94 ? "#09101d" : utilModule.colMuted)
                Behavior on color { ColorAnimation { duration: 90 } }

                MouseArea {
                    id: chevronMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: scard.headerClicked()
                }
            }
        }

        MouseArea {
            id: scardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function calcRatio(mouseX) {
                var startX = scard.height;
                var endX = width - (scard.showChevron ? 44 : 28);
                if (mouseX <= startX) return 0.0;
                if (mouseX >= endX) return 1.0;
                return (mouseX - startX) / (endX - startX);
            }

            onPressed: (mouse) => {
                if (mouse.x <= scard.height) {
                    scard.iconClicked();
                    return;
                }
                if (scard.showChevron && mouse.x >= width - 32) {
                    scard.headerClicked();
                    return;
                }
                scard.dragVal = calcRatio(mouse.x);
                scard.moved(scard.dragVal);
            }

            onPositionChanged: (mouse) => {
                if (!pressed || scard.dragVal < 0) return;
                scard.dragVal = calcRatio(mouse.x);
                scard.moved(scard.dragVal);
            }

            onReleased: {
                scard.dragVal = -1;
                utilModule.isDraggingBrightness = false;
                utilModule.isDraggingVolume = false;
            }

            onWheel: (wheel) => {
                var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                scard.moved(Math.max(0.0, Math.min(1.0, scard.currentRatio + step)));
            }
        }
    }

    // 5. Compact Tonal Squircle for Secondary Hardware Tools (Icon-only)
    component MaterialChipBtn: Rectangle {
        id: chip
        property string glyph: ""
        property bool lit: false
        property color tint: utilModule.colAccent
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 36
        radius: 12

        color: chip.lit ? Qt.rgba(chip.tint.r, chip.tint.g, chip.tint.b, 0.22) : (chipMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.05)

        scale: chipMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 110 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: chip.glyph
            fill: chip.lit ? 1 : 0
            iconSize: 18
            color: chip.lit ? chip.tint : utilModule.colText
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: chip.clicked()
        }
    }

    // 6. Compact 3D Header Quick Action Button
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
        anchors.topMargin: 3
        spacing: 7

        // ── TOP HEADER BAR ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8

            // Tactile Back / Exit Button
            Rectangle {
                width: 26; height: 26; radius: 8
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

            }
        }

        // ── 1. MAIN CONTROL CENTER VIEW (MATERIAL YOU) ─────────────
        ColumnLayout {
            id: mainViewContainer
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 4
            spacing: 6
            visible: utilModule.activeSection === ""

            // ROW 1: Wi-Fi Pill, Focus Pill, Lock Circle Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Wi-Fi Pill (Split: disc toggles Wi-Fi, body opens Wi-Fi module)
                MaterialPill {
                    glyph: (utilModule.activeNetType === "eth") ? "lan" : (utilModule.wifiEnabled ? "wifi" : "wifi_off")
                    title: (utilModule.activeNetType === "eth") ? "Ethernet" : (utilModule.wifiEnabled ? (utilModule.activeNetName !== "" ? utilModule.activeNetName : "Wi-Fi") : "Wi-Fi")
                    subtitle: {
                        if (utilModule.activeNetType === "eth") return "Connected";
                        if (!utilModule.wifiEnabled) return "Off";
                        if (utilModule.activeNetName !== "") {
                            return utilModule.activeNetSignal > 0 ? ("Connected • " + utilModule.activeNetSignal + "%") : "Connected";
                        }
                        return "Disconnected";
                    }
                    isActive: utilModule.wifiEnabled
                    isSplit: true
                    activeColor: utilModule.colAccent
                    onToggleClicked: utilModule.toggleWifi()
                    onDetailClicked: root.switchMode("wifi", false)
                }

                // Focus / DND Pill
                MaterialPill {
                    glyph: root.dndEnabled ? "do_not_disturb_on" : "do_not_disturb_off"
                    title: "Focus"
                    subtitle: root.dndEnabled ? "On" : "Off"
                    isActive: root.dndEnabled
                    isSplit: false
                    activeColor: utilModule.colAccent
                    onToggleClicked: root.dndEnabled = !root.dndEnabled
                }

                // Lock Circular Button
                MaterialCircleBtn {
                    glyph: "lock"
                    onClicked: {
                        root.collapseToIdle();
                        Quickshell.execDetached(["hyprlock"]);
                    }
                }
            }

            // ROW 2: Bluetooth Pill, Night Light Pill, Power Circle Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Bluetooth Pill (Split: disc toggles BT, body opens BT module)
                MaterialPill {
                    glyph: utilModule.btEnabled ? "bluetooth" : "bluetooth_disabled"
                    title: {
                        if (!utilModule.btEnabled) return "Bluetooth";
                        if (utilModule.activeBtName !== "") return utilModule.activeBtName;
                        return "Bluetooth";
                    }
                    subtitle: {
                        if (!utilModule.btEnabled) return "Off";
                        if (utilModule.activeBtName !== "") {
                            return utilModule.activeBtBattery !== "" ? ("Connected • " + utilModule.activeBtBattery) : "Connected";
                        }
                        return "Disconnected";
                    }
                    isActive: utilModule.btEnabled
                    isSplit: true
                    activeColor: utilModule.colAccent
                    onToggleClicked: utilModule.toggleBluetooth()
                    onDetailClicked: root.switchMode("bluetooth", false)
                }

                // Night Light Pill (hyprsunset)
                MaterialPill {
                    glyph: "nightlight"
                    title: "Night Light"
                    subtitle: utilModule.nightLightActive ? "On" : "Off"
                    isActive: utilModule.nightLightActive
                    isSplit: false
                    activeColor: utilModule.colAccent
                    onToggleClicked: utilModule.toggleNightLight()
                }

                // Power Circular Button
                MaterialCircleBtn {
                    glyph: "power_settings_new"
                    iconColor: "#ff5555"
                    customBg: Qt.rgba(255, 85, 85, 0.12)
                    hoverBg: Qt.rgba(255, 85, 85, 0.25)
                    onClicked: root.switchMode("powermenu", false)
                }
            }

            // ROW 3: Sound Slider (with chevron to audio devices subview)
            MaterialSliderCard {
                Layout.topMargin: 4
                value: utilModule.audioVolume
                icon: utilModule.audioMuted ? "volume_off" : (utilModule.audioVolume > 0.5 ? "volume_up" : (utilModule.audioVolume > 0 ? "volume_down" : "volume_mute"))
                percentText: utilModule.audioMuted ? "Muted" : (Math.round(utilModule.audioVolume * 100) + "%")
                muted: utilModule.audioMuted
                showChevron: true
                activeColor: utilModule.colAccent
                onMoved: (val) => {
                    utilModule.isDraggingVolume = true;
                    utilModule.setVolume(val);
                }
                onIconClicked: utilModule.toggleMute()
                onHeaderClicked: {
                    utilModule.activeSection = "audio";
                    fetchAudioDevices.running = true;
                }
            }

            // ROW 4: Display Slider
            MaterialSliderCard {
                value: utilModule.displayBrightness
                icon: "light_mode"
                percentText: Math.round(utilModule.displayBrightness * 100) + "%"
                showChevron: false
                activeColor: utilModule.colAccent
                onMoved: (val) => {
                    utilModule.isDraggingBrightness = true;
                    utilModule.setBrightness(val);
                }
                onIconClicked: utilModule.setBrightness(utilModule.displayBrightness > 0.5 ? 0.2 : 0.8)
            }

            // ROW 5: Secondary Hardware Tools Squircle Row (Mic, Caffeine, Capture, Record, Picker)
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6

                // 1. Microphone Mute
                MaterialChipBtn {
                    glyph: utilModule.audioMicMuted ? "mic_off" : "mic"
                    lit: !utilModule.audioMicMuted
                    tint: utilModule.audioMicMuted ? "#f7768e" : utilModule.colAccent
                    onClicked: utilModule.toggleMicMute()
                }

                // 2. Caffeine (sleep inhibitor)
                MaterialChipBtn {
                    glyph: "coffee"
                    lit: utilModule.caffeineActive
                    tint: "#ff9e64"
                    onClicked: utilModule.toggleCaffeine()
                }

                // 3. Screen Capture (grim + slurp)
                MaterialChipBtn {
                    glyph: "crop"
                    lit: false
                    tint: "#2ac3de"
                    onClicked: utilModule.triggerScreenshot()
                }

                // 4. Screen Record
                MaterialChipBtn {
                    glyph: (typeof recMod !== "undefined" && recMod.isRecording) ? "stop_circle" : "radio_button_checked"
                    lit: typeof recMod !== "undefined" && recMod.isRecording
                    tint: "#f7768e"
                    onClicked: root.switchMode("recorder", false)
                }

                // 5. Color Picker (hyprpicker)
                MaterialChipBtn {
                    glyph: "colorize"
                    lit: false
                    tint: "#7dcfff"
                    onClicked: utilModule.triggerColorPicker()
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

            // Tactile Back Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: audioBackMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: utilModule.colText
                    }

                    MouseArea {
                        id: audioBackMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: utilModule.activeSection = ""
                    }
                }

                Text {
                    text: "OUTPUT AUDIO SINKS"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: utilModule.colMuted
                }
            }

            Repeater {
                model: utilModule.audioSinks
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: 14
                    color: modelData.isDefault ? Qt.rgba(utilModule.colAccent.r, utilModule.colAccent.g, utilModule.colAccent.b, 0.20) : (sinkMouse.containsMouse ? utilModule.colCardHover : utilModule.colCard)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.06)

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
                    border.color: Qt.rgba(255, 255, 255, 0.06)

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
