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
    component QsStadiumTile: Rectangle {
        id: tileRoot
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property color activeColor: batteryModule.accentColor
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 48
        radius: 24

        // Smooth background tone: soft tinted container when active, dark surface when inactive
        color: active 
            ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.16)
            : (tileMouse.containsMouse ? batteryModule.hoverBg : batteryModule.cardBg)

        border.width: 1
        border.color: active
            ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.35)
            : (tileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))

        // Tactile press & hover scale bounce
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
            anchors.leftMargin: 6
            anchors.rightMargin: 12
            spacing: 9

            // Large circular icon container on the left
            Rectangle {
                id: iconCircle
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: tileRoot.active ? tileRoot.activeColor : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: tileRoot.icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                    color: tileRoot.active ? batteryModule.bgBase : batteryModule.textSecondary
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            // Title and state subtitle
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: tileRoot.title
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.bold: true
                    color: batteryModule.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: tileRoot.subtitle
                    font.family: "Inter"
                    font.pixelSize: 9
                    color: tileRoot.active ? tileRoot.activeColor : batteryModule.textSecondary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    // ========================================================
    // MAIN DASHBOARD LAYOUT
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ══════════════════════════════════════════════════════════
        // 1. MATERIAL YOU BATTERY SLIDER HERO (Android Sound/Display style)
        // ══════════════════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            // Header line: Title, Status Pill, and Time Estimation
            RowLayout {
                Layout.fillWidth: true

                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "Battery"
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.bold: true
                        color: batteryModule.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        height: 20
                        radius: 10
                        color: Qt.rgba(batteryModule.statusColor.r, batteryModule.statusColor.g, batteryModule.statusColor.b, 0.16)
                        border.width: 1
                        border.color: Qt.rgba(batteryModule.statusColor.r, batteryModule.statusColor.g, batteryModule.statusColor.b, 0.3)
                        width: pillRow.implicitWidth + 12
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            id: pillRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: batteryModule.isCharging ? "󱐋" : (batteryModule.isFull ? "󰚥" : "󰁹")
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: batteryModule.statusColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: batteryModule.isCharging ? "AC Fast Charging" : (batteryModule.isFull ? "AC Connected" : "Discharging")
                                font.family: "Inter"
                                font.pixelSize: 9
                                font.bold: true
                                color: batteryModule.statusColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 5
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "󱑂"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: batteryModule.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: batteryModule.timeRemainingStr
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.bold: true
                        color: batteryModule.accentColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Chunky Material You Stadium Battery Bar (just like Sound/Display sliders in attachment)
            Rectangle {
                id: batteryBarContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 22
                color: batteryModule.hoverBg
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)
                clip: true

                // Active Filled Stadium Capsule
                Rectangle {
                    id: batteryFill
                    height: parent.height
                    radius: 22
                    color: batteryModule.statusColor
                    width: Math.max(height, parent.width * (Math.min(100, Math.max(0, batteryModule.batteryLevel)) / 100.0))

                    Behavior on width {
                        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                    }

                    // Embedded icon circle inside the active fill
                    Rectangle {
                        id: batteryIconCircle
                        width: 32
                        height: 32
                        radius: 16
                        color: Qt.rgba(0, 0, 0, 0.16)
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: batteryModule.isCharging ? "󱐋" : (batteryModule.isLowLevel ? "󰂃" : "󰁹")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15
                            font.bold: true
                            color: batteryModule.bgBase
                        }
                    }

                    // Bold Percentage inside the fill
                    Text {
                        anchors.left: batteryIconCircle.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: batteryModule.batteryLevel + "%"
                        font.family: "Inter"
                        font.pixelSize: 15
                        font.bold: true
                        font.features: { "tnum": 1 }
                        color: batteryModule.bgBase
                    }
                }

                // Live Telemetry stats on the right side of the stadium bar
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Text {
                        text: (batteryModule.currentPowerW > 0 ? batteryModule.currentPowerW.toFixed(1) + " W" : "0.0 W")
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.bold: true
                        color: batteryFill.width > parent.width - 95 ? batteryModule.bgBase : batteryModule.textPrimary
                    }
                    Text {
                        text: "•"
                        font.pixelSize: 11
                        color: batteryFill.width > parent.width - 95 ? batteryModule.bgBase : batteryModule.textSecondary
                        opacity: 0.6
                    }
                    Text {
                        text: batteryModule.voltageV.toFixed(1) + " V"
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.bold: true
                        color: batteryFill.width > parent.width - 95 ? batteryModule.bgBase : batteryModule.textPrimary
                    }
                }
            }

            // Health & Capacity summary line
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Health: " + batteryModule.healthPercentage + "% (" + (batteryModule.healthPercentage > 80 ? "Good" : "Fair") + ")"
                    font.family: "Inter"
                    font.pixelSize: 9
                    color: batteryModule.textSecondary
                }

                // Thin health progress bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(1, 1, 1, 0.08)
                    clip: true

                    Rectangle {
                        width: parent.width * (Math.min(100, Math.max(0, batteryModule.healthPercentage)) / 100.0)
                        height: parent.height
                        radius: 1.5
                        color: batteryModule.healthPercentage > 75 ? batteryModule.accentColor : batteryModule.warningColor
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                }

                Text {
                    text: batteryModule.currentEnergyWh.toFixed(1) + " / " + batteryModule.fullEnergyWh.toFixed(1) + " Wh"
                    font.family: "Inter"
                    font.pixelSize: 9
                    font.bold: true
                    color: batteryModule.textSecondary
                }
            }
        }

        // ══════════════════════════════════════════════════════════
        // 2. MATERIAL YOU POWER PROFILES (Stadium Capsule Pills)
        // ══════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
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
                    radius: 20

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
                        anchors.leftMargin: 5
                        anchors.rightMargin: 10
                        spacing: 7

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
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
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.bold: true
                            color: profilePill.isSelected ? batteryModule.accentColor : batteryModule.textPrimary
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════
        // 3. ANDROID QUICK SETTINGS 2x2 GRID OF STADIUM TILES
        // (Identical visual pattern to Wi-Fi/Bluetooth tiles in attachment)
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

        // ══════════════════════════════════════════════════════════
        // 4. TOP BATTERY CONSUMERS (Material You App Usage Pills)
        // ══════════════════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            // Header line with Refresh Icon
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Top Battery Consumers"
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.bold: true
                    color: batteryModule.textPrimary
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: refreshMouse.containsMouse ? batteryModule.hoverBg : "transparent"

                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: batteryModule.textSecondary
                        rotation: 0

                        RotationAnimation on rotation {
                            id: spinAnim
                            running: false
                            from: 0
                            to: 360
                            duration: 500
                            easing.type: Easing.OutCubic
                        }
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            spinAnim.restart();
                            telemetryPoller.running = true;
                        }
                    }
                }
            }

            // App Consumer Pills
            Repeater {
                model: batteryModule.topDrainers.length > 0 ? batteryModule.topDrainers.slice(0, 3) : []

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 18
                    color: batteryModule.cardBg
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 10
                        spacing: 8

                        // App Icon in rounded circle
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: Qt.rgba(1, 1, 1, 0.06)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon || "󰘚"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: batteryModule.accentColor
                            }
                        }

                        // App name and PID
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name || "Process"
                                    font.family: "Inter"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: batteryModule.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "PID " + (modelData.pid || "-")
                                    font.family: "Inter"
                                    font.pixelSize: 8
                                    color: batteryModule.textSecondary
                                }
                            }

                            // Micro Load Bar
                            Rectangle {
                                Layout.fillWidth: true
                                height: 3
                                radius: 1.5
                                color: Qt.rgba(1, 1, 1, 0.06)
                                clip: true

                                Rectangle {
                                    property real cpuNum: modelData.cpuNum !== undefined ? modelData.cpuNum : (parseFloat(modelData.cpu) || 0)
                                    width: parent.width * Math.min(1.0, Math.max(0.05, cpuNum / 100.0))
                                    height: parent.height
                                    radius: 1.5
                                    color: cpuNum >= 20 ? batteryModule.warningColor : batteryModule.accentColor
                                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                                }
                            }
                        }

                        // Chunky Material You Usage Capsule Badge
                        Rectangle {
                            Layout.preferredHeight: 20
                            radius: 10
                            color: Qt.rgba(batteryModule.accentColor.r, batteryModule.accentColor.g, batteryModule.accentColor.b, 0.16)
                            border.width: 1
                            border.color: Qt.rgba(batteryModule.accentColor.r, batteryModule.accentColor.g, batteryModule.accentColor.b, 0.3)
                            Layout.preferredWidth: cpuValText.implicitWidth + 10

                            Text {
                                id: cpuValText
                                anchors.centerIn: parent
                                text: modelData.cpu || "0%"
                                font.family: "Inter"
                                font.pixelSize: 9
                                font.bold: true
                                color: batteryModule.accentColor
                            }
                        }
                    }
                }
            }

            // Fallback when scanning
            Item {
                visible: batteryModule.topDrainers.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰂑"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: batteryModule.textSecondary
                    }
                    Text {
                        text: "Scanning background power draw..."
                        font.family: "Inter"
                        font.pixelSize: 9
                        color: batteryModule.textSecondary
                    }
                }
            }
        }
    }
}
