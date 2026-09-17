import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../"

Item {
    id: batteryModule
    Layout.fillWidth: true
    Layout.fillHeight: true

    // ========================================================
    // MATERIAL YOU / M3 COLOR TOKENS
    // ========================================================
    readonly property color accentColor: Theme.colors.accent ?? "#a7c080"
    readonly property color cardBg: Theme.colors.card_bg ?? "#1a211f"
    readonly property color hoverBg: Theme.colors.hover_bg ?? "#242f2b"
    readonly property color borderColor: Theme.colors.border ?? "#313f39"
    readonly property color borderHover: Theme.colors.border_hover ?? accentColor
    readonly property color textPrimary: Theme.colors.text_primary ?? "#d3c6aa"
    readonly property color textSecondary: Theme.colors.text_secondary ?? "#9da9a0"
    readonly property color bgBase: Theme.colors.bg ?? "#121716"

    readonly property color chargingColor: "#8FDEB4"
    readonly property color warningColor: "#e0af68"
    readonly property color errorColor: "#e67e80"

    // ========================================================
    // REACTIVE HARDWARE STATE
    // ========================================================
    readonly property var upowerDev: typeof UPower !== "undefined" ? UPower.displayDevice : null

    property int rawBatteryLevel: 98
    property bool rawIsCharging: false
    property bool rawIsFull: false

    property int batteryLevel: (upowerDev && upowerDev.percentage !== undefined && upowerDev.percentage > 0)
        ? Math.round(upowerDev.percentage * 100)
        : rawBatteryLevel

    property bool isCharging: (upowerDev && upowerDev.state !== undefined)
        ? (upowerDev.state === UPowerDevice.Charging)
        : rawIsCharging

    property bool isFull: (upowerDev && upowerDev.state !== undefined)
        ? (upowerDev.state === UPowerDevice.FullyCharged || (batteryLevel >= 96 && upowerDev.state !== UPowerDevice.Discharging))
        : rawIsFull

    readonly property bool isWarningLevel: batteryLevel <= 25 && batteryLevel > 15 && !isCharging
    readonly property bool isLowLevel: batteryLevel <= 15 && !isCharging

    readonly property color statusColor: {
        if (isCharging) return chargingColor;
        if (isLowLevel) return errorColor;
        if (isWarningLevel) return warningColor;
        return accentColor;
    }

    // Telemetry properties
    property real currentPowerW: 10.7
    property real voltageV: 12.0
    property real currentEnergyWh: 37.7
    property real fullEnergyWh: 38.9
    property int healthPercentage: 77
    property string timeRemainingStr: "Calculating..."
    property int chargeThreshold: 100
    property int refreshRate: 144
    property int kbdBacklight: 0
    property var topDrainers: []
    property string activeProfile: "balanced"

    // ========================================================
    // BACKEND SCRIPTS INTEGRATION
    // ========================================================
    readonly property string scriptPath: (Quickshell.shellDir || Quickshell.configDir) + "/scripts/battery_telemetry.py"

    Process {
        id: telemetryPoller
        running: false
        command: ["python3", batteryModule.scriptPath, "telemetry"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var data = JSON.parse(this.text.trim());
                    if (data.percentage !== undefined) batteryModule.rawBatteryLevel = data.percentage;
                    if (data.isCharging !== undefined) batteryModule.rawIsCharging = !!data.isCharging;
                    if (data.isFull !== undefined) batteryModule.rawIsFull = !!data.isFull;
                    if (data.powerW !== undefined) batteryModule.currentPowerW = data.powerW;
                    if (data.voltageV !== undefined) batteryModule.voltageV = data.voltageV;
                    if (data.health !== undefined) batteryModule.healthPercentage = Math.min(100, Math.max(0, data.health));
                    if (data.currentEnergyWh !== undefined) batteryModule.currentEnergyWh = data.currentEnergyWh;
                    if (data.fullEnergyWh !== undefined) batteryModule.fullEnergyWh = data.fullEnergyWh;
                    if (data.timeStr !== undefined) batteryModule.timeRemainingStr = data.timeStr;
                    if (data.chargeThreshold !== undefined) batteryModule.chargeThreshold = data.chargeThreshold;
                    if (data.refreshRate !== undefined) batteryModule.refreshRate = data.refreshRate;
                    if (data.kbdBacklight !== undefined) batteryModule.kbdBacklight = data.kbdBacklight;
                    if (data.topDrainers) batteryModule.topDrainers = data.topDrainers;
                } catch (e) {
                    console.warn("[BatteryModule] Telemetry parse error:", e);
                }
            }
        }
    }

    Process {
        id: profileChecker
        running: false
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null || echo 'balanced'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim();
                if (p !== "") batteryModule.activeProfile = p;
            }
        }
    }

    Process {
        id: actionRunner
        running: false
        onExited: {
            telemetryPoller.running = true;
        }
    }

    function runTelemetryAction(cmdArgs) {
        actionRunner.command = ["python3", batteryModule.scriptPath].concat(cmdArgs);
        actionRunner.running = true;
    }

    function toggleRefreshRate() {
        batteryModule.refreshRate = (batteryModule.refreshRate <= 60) ? 144 : 60;
        runTelemetryAction(["toggle_hz"]);
    }

    function toggleKbdBacklight() {
        batteryModule.kbdBacklight = (batteryModule.kbdBacklight === 0) ? 2 : 0;
        runTelemetryAction(["toggle_kbd"]);
    }

    function toggleChargeThreshold() {
        var next = (batteryModule.chargeThreshold === 80) ? 100 : 80;
        batteryModule.chargeThreshold = next;
        runTelemetryAction(["set_threshold", next.toString()]);
    }

    function setPowerProfile(profileName) {
        batteryModule.activeProfile = profileName;
        Quickshell.execDetached(["powerprofilesctl", "set", profileName]);
    }

    function pollAll() {
        if (!telemetryPoller.running) telemetryPoller.running = true;
        if (!profileChecker.running) profileChecker.running = true;
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode === "battery") {
                batteryModule.pollAll();
            }
        }
    }

    Timer {
        interval: 2500
        running: root.activeMode === "battery"
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryModule.pollAll()
    }

    Component.onCompleted: {
        batteryModule.pollAll();
    }

    // ========================================================
    // REUSABLE MATERIAL YOU QUICK SETTINGS STADIUM TILE
    // (Matches Android Quick Settings tiles shown in attachment)
    // ========================================================
    // ========================================================
    // REUSABLE MATERIAL YOU QUICK SETTINGS STADIUM TILE
    // ========================================================
    component QsStadiumTile: Rectangle {
        id: tileRoot
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property color activeColor: batteryModule.accentColor
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: 16

        // Smooth background tone: soft tinted container when active, dark surface when inactive
        color: active 
            ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.16)
            : (tileMouse.containsMouse ? batteryModule.hoverBg : batteryModule.cardBg)

        border.width: 1
        border.color: active
            ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.35)
            : (tileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))

        scale: tileMouse.pressed ? 0.96 : (tileMouse.containsMouse ? 1.01 : 1.0)
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tileRoot.clicked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 9

            // Circular icon container on the left
            Rectangle {
                id: iconCircle
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: tileRoot.active ? tileRoot.activeColor : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: tileRoot.icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.bold: true
                    color: tileRoot.active ? batteryModule.bgBase : batteryModule.textSecondary
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            // Title and state subtitle
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: tileRoot.title
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: batteryModule.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    renderType: Text.NativeRendering
                }

                Text {
                    text: tileRoot.subtitle
                    font.family: "Noto Sans"
                    font.pixelSize: 9
                    font.weight: Font.Normal
                    color: tileRoot.active ? tileRoot.activeColor : batteryModule.textSecondary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // ========================================================
    // MAIN DASHBOARD LAYOUT
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        // ══════════════════════════════════════════════════════════
        // 1. HERO BATTERY DISPLAY (Modern, Minimalist & Eye-Pleasing)
        // ══════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            radius: 18
            color: batteryModule.cardBg
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.05)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Top Line: Icon badge + Big Percentage + State subtitle & Time + Right Telemetry
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 11

                    // Tactile Back to Utility Button
                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: battBackMouse.containsMouse ? batteryModule.hoverBg : "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        scale: battBackMouse.pressed ? 0.90 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰁍"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: batteryModule.textPrimary
                        }

                        MouseArea {
                            id: battBackMouse
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.switchMode("utility", true)
                        }
                    }

                    // Refined circular icon badge
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: Qt.rgba(batteryModule.statusColor.r, batteryModule.statusColor.g, batteryModule.statusColor.b, 0.16)

                        Text {
                            anchors.centerIn: parent
                            text: batteryModule.isCharging ? "󱐋" : (batteryModule.isFull ? "󰚥" : (batteryModule.isLowLevel ? "󰂃" : "󰁹"))
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            color: batteryModule.statusColor
                        }
                    }

                    // Percentage and Status info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8

                            Text {
                                text: batteryModule.batteryLevel + "%"
                                font.family: "Noto Sans"
                                font.pixelSize: 22
                                font.weight: Font.Bold
                                color: batteryModule.textPrimary
                                renderType: Text.NativeRendering
                            }

                            // Subtle state badge
                            Rectangle {
                                height: 18
                                radius: 9
                                color: Qt.rgba(batteryModule.statusColor.r, batteryModule.statusColor.g, batteryModule.statusColor.b, 0.15)
                                width: stateText.implicitWidth + 12

                                Text {
                                    id: stateText
                                    anchors.centerIn: parent
                                    text: batteryModule.isCharging ? "Charging" : (batteryModule.isFull ? "Fully Charged" : "Discharging")
                                    font.family: "Noto Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: batteryModule.statusColor
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        Text {
                            text: {
                                if (batteryModule.isFull) return "AC Power Connected";
                                if (batteryModule.timeRemainingStr && batteryModule.timeRemainingStr !== "Calculating...") {
                                    return batteryModule.timeRemainingStr;
                                }
                                return batteryModule.isCharging ? "Fast Charging" : "Calculating remaining time...";
                            }
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            color: batteryModule.textSecondary
                            renderType: Text.NativeRendering
                        }
                    }

                    // Power draw rate and health badge on right
                    ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        Text {
                            text: (batteryModule.currentPowerW > 0 ? batteryModule.currentPowerW.toFixed(1) + " W" : "0.0 W")
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: batteryModule.statusColor
                            Layout.alignment: Qt.AlignRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: batteryModule.healthPercentage + "% Health"
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            color: batteryModule.textSecondary
                            Layout.alignment: Qt.AlignRight
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // Sleek, refined, slim progress track (not a bulky 44px block)
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.08)
                    clip: true

                    Rectangle {
                        height: parent.height
                        radius: 3
                        color: batteryModule.statusColor
                        width: parent.width * (Math.min(100, Math.max(0, batteryModule.batteryLevel)) / 100.0)

                        Behavior on width {
                            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════
        // 2. POWER PROFILES (Power Saver / Balanced / Performance)
        // ══════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 8

            readonly property var profiles: [
                { id: "power-saver", label: "Power Saver", icon: "󰌪" },
                { id: "balanced",    label: "Balanced",    icon: "󰾅" },
                { id: "performance", label: "Performance", icon: "󰓅" }
            ]

            Repeater {
                model: parent.profiles

                Rectangle {
                    id: profilePill
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 19

                    readonly property bool isSelected: batteryModule.activeProfile === modelData.id

                    color: isSelected 
                        ? Qt.rgba(batteryModule.accentColor.r, batteryModule.accentColor.g, batteryModule.accentColor.b, 0.18)
                        : (profMouse.containsMouse ? batteryModule.hoverBg : batteryModule.cardBg)

                    border.width: 1
                    border.color: isSelected
                        ? Qt.rgba(batteryModule.accentColor.r, batteryModule.accentColor.g, batteryModule.accentColor.b, 0.35)
                        : (profMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))

                    scale: profMouse.pressed ? 0.96 : (profMouse.containsMouse ? 1.01 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: profMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: batteryModule.setPowerProfile(modelData.id)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 10
                        spacing: 7

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: profilePill.isSelected ? batteryModule.accentColor : Qt.rgba(1, 1, 1, 0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: profilePill.isSelected ? batteryModule.bgBase : batteryModule.textSecondary
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: profilePill.isSelected ? batteryModule.accentColor : batteryModule.textPrimary
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════
        // 3. HARDWARE & ECO TILES (2x2 Grid)
        // ══════════════════════════════════════════════════════════
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            // Tile 1: Battery Care (80% Asus Charge Threshold)
            QsStadiumTile {
                icon: "󱊞"
                title: "Battery Care"
                subtitle: batteryModule.chargeThreshold === 80 ? "80% Limit (Healthy)" : "100% Full Capacity"
                active: batteryModule.chargeThreshold === 80
                activeColor: batteryModule.accentColor
                onClicked: batteryModule.toggleChargeThreshold()
            }

            // Tile 2: Display 60Hz Eco Mode
            QsStadiumTile {
                icon: "󰍹"
                title: "Display Eco"
                subtitle: batteryModule.refreshRate <= 60 ? "60 Hz Active (~2W saved)" : "144 Hz Smooth"
                active: batteryModule.refreshRate <= 60
                activeColor: batteryModule.accentColor
                onClicked: batteryModule.toggleRefreshRate()
            }

            // Tile 3: Keyboard Backlight
            QsStadiumTile {
                icon: "󰌌"
                title: "Kbd Backlight"
                subtitle: batteryModule.kbdBacklight > 0 ? "Illumination On" : "Off (Power Saver)"
                active: batteryModule.kbdBacklight > 0
                activeColor: batteryModule.accentColor
                onClicked: batteryModule.toggleKbdBacklight()
            }

            // Tile 4: Instant Telemetry / Power Draw Rate
            QsStadiumTile {
                icon: "󱐋"
                title: "Power Draw"
                subtitle: (batteryModule.currentPowerW > 0 ? batteryModule.currentPowerW.toFixed(1) + " W rate" : "0.0 W idle") + " • " + batteryModule.voltageV.toFixed(1) + "V"
                active: batteryModule.isCharging
                activeColor: batteryModule.chargingColor
                onClicked: batteryModule.pollAll()
            }
        }
    }
}
