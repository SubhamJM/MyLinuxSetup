import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../"

ColumnLayout {
    id: btModule
    spacing: 8
    Layout.fillWidth: true

    // Material UI Neutral Deep Black Tokens
    readonly property color colSurface: "#000000"
    readonly property color colCard: "#0e0e12"
    readonly property color colCardHover: "#18181c"
    readonly property color colCardActive: "#141418"
    readonly property color colChipBg: "#141418"
    readonly property color colText: "#f8fafc"
    readonly property color colSubtext: "#94a3b8"
    readonly property color colMuted: "#64748b"
    readonly property color colAccent: Theme.colors.accent ?? "#88c0d0"
    readonly property color colGreen: ({ nord: "#a3be8c", dracula: "#50fa7b", catppuccin: "#a6e3a1", everforest: "#a7c080", "rose-pine": "#9ccfd8" })[Theme.currentThemeName] ?? "#30d158"
    readonly property color colRed: ({ nord: "#bf616a", dracula: "#ff5555", catppuccin: "#f38ba8", everforest: "#e67e80", "rose-pine": "#eb6f92" })[Theme.currentThemeName] ?? "#ff453a"

    // State maps for expanded cards and live device batteries
    property var stateMap: ({})
    property var batteryMap: ({})

    readonly property var adapter: typeof Bluetooth !== "undefined" ? Bluetooth.defaultAdapter : null
    readonly property bool isEnabled: adapter ? adapter.enabled : false
    readonly property bool isDiscovering: adapter ? adapter.discovering : false

    // Batch Bluetooth Battery Scanner (queries battery percentage for all known devices)
    Process {
        id: btBatchBatteryScanner
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/bt-status.py").toString().replace("file://", ""), "--all"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var bmap = {};
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("=") !== -1) {
                        var p = line.split("=");
                        if (p[0] && p[1]) {
                            bmap[p[0]] = p[1];
                        }
                    }
                }
                btModule.batteryMap = bmap;
            }
        }
    }

    // Refresh scanner periodically when Bluetooth popup is active
    Timer {
        interval: 2500
        running: (root.activeMode === "bluetooth" || (root.activeMode === "utility" && typeof utilMod !== "undefined" && utilMod.activeSection === "bluetooth")) && btModule.isEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!btBatchBatteryScanner.running) btBatchBatteryScanner.running = true;
        }
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if ((root.activeMode === "bluetooth" || (root.activeMode === "utility" && typeof utilMod !== "undefined" && utilMod.activeSection === "bluetooth")) && btModule.isEnabled) {
                btBatchBatteryScanner.running = true;
            }
        }
    }

    function toggleExpand(mac) {
        var sm = Object.assign({}, btModule.stateMap);
        if (!sm[mac]) sm[mac] = { isExpanded: false };
        sm[mac].isExpanded = !sm[mac].isExpanded;
        btModule.stateMap = sm;
    }

    // Device icon mapper based on hints
    function iconFor(dev) {
        var icon = (dev.device && dev.device.icon) ? dev.device.icon.toLowerCase() : "";
        var name = (dev.name || "").toLowerCase();
        if (icon.includes("audio") || icon.includes("headset") || icon.includes("headphone") ||
            name.includes("bud") || name.includes("pod") || name.includes("wh-") || name.includes("headphone") || name.includes("ear")) {
            return "󰋋";
        }
        if (icon.includes("phone") || name.includes("phone") || name.includes("iphone") || name.includes("android")) return "󰄜";
        if (icon.includes("computer") || icon.includes("laptop") || name.includes("mac") || name.includes("pc")) return "󰌢";
        if (icon.includes("mouse") || name.includes("mouse") || name.includes("trackpad")) return "󰍽";
        if (icon.includes("keyboard") || name.includes("keyboard") || name.includes("key")) return "󰌌";
        if (icon.includes("gamepad") || icon.includes("joystick") || name.includes("controller")) return "󰊖";
        return dev.connected ? "󰂱" : "󰂯";
    }

    function batteryIconFor(pct) {
        if (pct >= 90) return "󰁹";
        if (pct >= 80) return "󰂂";
        if (pct >= 60) return "󰁿";
        if (pct >= 40) return "󰁽";
        if (pct >= 20) return "󰁻";
        return "󰂎";
    }

    // Connected device summary helper
    readonly property var primaryConnectedDevice: {
        for (var i = 0; i < filteredDevices.length; i++) {
            if (filteredDevices[i].connected) return filteredDevices[i];
        }
        return null;
    }

    readonly property string primaryBattery: {
        if (!primaryConnectedDevice) return "";
        if (typeof dashMod !== "undefined" && dashMod.btConnectedMac === primaryConnectedDevice.mac && dashMod.btIslandBattery !== "") {
            return dashMod.btIslandBattery;
        }
        return batteryMap[primaryConnectedDevice.mac] || "";
    }

    readonly property var filteredDevices: {
        if (typeof Bluetooth === "undefined" || !Bluetooth.devices) return [];
        var rawList = Bluetooth.devices.values;
        var seenKeys = {};
        var result = [];

        for (var i = 0; i < rawList.length; i++) {
            var dev = rawList[i];
            var devName = dev.name ? dev.name.trim() : "";
            var mac = dev.address ? dev.address.trim() : "";
            if (!mac && !devName) continue;

            // Filter out anonymous raw MAC hex addresses unless paired or connected
            var isRawMac = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/.test(devName) || 
                           /^([0-9A-Fa-f]{2}-){5}([0-9A-Fa-f]{2})$/.test(devName);
            if (isRawMac && !dev.paired && !dev.connected) continue;
            if (devName === "" && !dev.paired && !dev.connected) continue;

            var key = mac || devName;
            if (!seenKeys[key]) {
                seenKeys[key] = true;
                result.push({
                    "device": dev,
                    "mac": mac,
                    "name": devName || mac,
                    "connected": dev.connected,
                    "paired": dev.paired
                });
            }
        }

        return result.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
    }

    // ========================================================
    // 1. HERO STATUS CARD (Material UI Solid Surface, No Border)
    // ========================================================
    Rectangle {
        Layout.fillWidth: true
        height: 94
        radius: 14
        color: btModule.colCard
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
                    color: btBackMouse.containsMouse ? btModule.colCardHover : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    scale: btBackMouse.pressed ? 0.90 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: btModule.colText
                    }

                    MouseArea {
                        id: btBackMouse
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
                    color: btModule.primaryConnectedDevice ? Qt.alpha(btModule.colAccent, 0.18) : btModule.colChipBg
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (!btModule.isEnabled) return "󰂲";
                            if (btModule.primaryConnectedDevice) return btModule.iconFor(btModule.primaryConnectedDevice);
                            return "󰂯";
                        }
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: {
                            if (!btModule.isEnabled) return btModule.colMuted;
                            if (btModule.primaryConnectedDevice) return btModule.colAccent;
                            return btModule.colText;
                        }
                    }
                }

                // Title + Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!btModule.isEnabled) return "Bluetooth Disabled";
                            if (btModule.primaryConnectedDevice) return btModule.primaryConnectedDevice.name;
                            return "Bluetooth Ready";
                        }
                        font.family: "Noto Sans"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: btModule.colText
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!btModule.isEnabled) return "Turn on to discover & pair devices";
                            if (btModule.primaryConnectedDevice) return "Connected • Active Audio Sink";
                            return "Discoverable to nearby devices";
                        }
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        color: btModule.colSubtext
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                // Solid Status Pill
                Rectangle {
                    radius: 10
                    color: {
                        if (!btModule.isEnabled) return btModule.colChipBg;
                        if (btModule.primaryConnectedDevice) return Qt.alpha(btModule.colGreen, 0.18);
                        return Qt.alpha(btModule.colAccent, 0.16);
                    }
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
                            color: {
                                if (!btModule.isEnabled) return btModule.colMuted;
                                if (btModule.primaryConnectedDevice) return btModule.colGreen;
                                return btModule.colAccent;
                            }
                            // Subtle breathing pulse when connected
                            SequentialAnimation on opacity {
                                running: btModule.isEnabled && (btModule.primaryConnectedDevice !== null)
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            text: {
                                if (!btModule.isEnabled) return "OFF";
                                if (btModule.primaryConnectedDevice) return "CONNECTED";
                                return "READY";
                            }
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                            color: {
                                if (!btModule.isEnabled) return btModule.colMuted;
                                if (btModule.primaryConnectedDevice) return btModule.colGreen;
                                return btModule.colAccent;
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Bottom Tonal Metadata Chips Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Chip 1: MAC / Adapter Address
                Rectangle {
                    height: 22
                    radius: 6
                    color: btModule.colChipBg
                    border.width: 0
                    implicitWidth: chipMacRow.implicitWidth + 12

                    Row {
                        id: chipMacRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰌢"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: btModule.colMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: btModule.primaryConnectedDevice ? btModule.primaryConnectedDevice.mac : (btModule.adapter ? (btModule.adapter.name || "hci0") : "hci0")
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: btModule.colSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Chip 2: Battery Percentage (Only if primary device has battery)
                Rectangle {
                    visible: btModule.primaryConnectedDevice !== null && btModule.primaryBattery !== ""
                    height: 22
                    radius: 6
                    color: {
                        var pct = parseInt(btModule.primaryBattery) || 100;
                        return pct < 20 ? Qt.alpha(btModule.colRed, 0.22) : btModule.colChipBg;
                    }
                    border.width: 0
                    implicitWidth: chipBatRow.implicitWidth + 12

                    Row {
                        id: chipBatRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: {
                                var pct = parseInt(btModule.primaryBattery) || 100;
                                return btModule.batteryIconFor(pct);
                            }
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: {
                                var pct = parseInt(btModule.primaryBattery) || 100;
                                return pct < 20 ? btModule.colRed : btModule.colAccent;
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: btModule.primaryBattery
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                            color: {
                                var pct = parseInt(btModule.primaryBattery) || 100;
                                return pct < 20 ? btModule.colRed : btModule.colText;
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Chip 3: State Chip (e.g. "Audio Sink" or "Scanning Active")
                Rectangle {
                    height: 22
                    radius: 6
                    color: btModule.isDiscovering ? Qt.alpha(btModule.colAccent, 0.2) : btModule.colChipBg
                    border.width: 0
                    implicitWidth: chipStateRow.implicitWidth + 12

                    Row {
                        id: chipStateRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: btModule.isDiscovering ? "󰑓" : (btModule.primaryConnectedDevice ? "󰓃" : "󰂯")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: btModule.isDiscovering ? btModule.colAccent : btModule.colMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: btModule.isDiscovering ? "Scanning" : (btModule.primaryConnectedDevice ? "High Quality" : "Bluetooth 5.3")
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: btModule.isDiscovering ? btModule.colAccent : btModule.colSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // ========================================================
    // 2. ACTION STRIP & POWER TOGGLE (Solid M3 Controls, No Border)
    // ========================================================
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // Section Title + Paired Count Capsule
        Row {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "Paired Devices"
                font.family: "Noto Sans"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                color: btModule.colText
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                height: 18
                radius: 9
                color: btModule.colChipBg
                border.width: 0
                implicitWidth: countText.implicitWidth + 10
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: btModule.filteredDevices.length + " paired"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: btModule.colSubtext
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Solid Scanning Pill Button
        Rectangle {
            height: 26
            radius: 13
            color: btModule.isDiscovering ? btModule.colAccent : btModule.colChipBg
            border.width: 0
            implicitWidth: scanRow.implicitWidth + 16
            visible: btModule.isEnabled

            Row {
                id: scanRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: "󰑓"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: btModule.isDiscovering ? btModule.colSurface : btModule.colText
                    anchors.verticalCenter: parent.verticalCenter
                    RotationAnimation on rotation {
                        running: btModule.isDiscovering
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                    }
                }
                Text {
                    text: btModule.isDiscovering ? "Scanning" : "Scan"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    color: btModule.isDiscovering ? btModule.colSurface : btModule.colText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (btModule.adapter) btModule.adapter.discovering = !btModule.adapter.discovering;
                }
            }
        }

        // Material You Solid Power Switch (Zero Borders)
        Item {
            implicitWidth: 40
            implicitHeight: 22

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: btModule.isEnabled ? btModule.colAccent : btModule.colChipBg
                border.width: 0
                Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: btModule.isEnabled ? parent.width - width - 3 : 3
                    color: btModule.isEnabled ? btModule.colSurface : btModule.colSubtext
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (btModule.adapter) btModule.adapter.enabled = !btModule.adapter.enabled;
                }
            }
        }
    }

    // ========================================================
    // 3. DEVICE CARDS LIST (Material UI Solid Polygon Cards)
    // ========================================================
    ListView {
        id: deviceListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: btModule.isEnabled ? btModule.filteredDevices : []

        // Empty state when Bluetooth is OFF or no devices found
        Item {
            anchors.fill: parent
            visible: !btModule.isEnabled || btModule.filteredDevices.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 44
                    height: 44
                    radius: 14
                    color: btModule.colChipBg
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: btModule.isEnabled ? "󰂯" : "󰂲"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: btModule.colMuted
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: !btModule.isEnabled ? "Bluetooth is Turned Off" : (btModule.isDiscovering ? "Searching for devices..." : "No paired devices found")
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    color: btModule.colSubtext
                }
            }
        }

        delegate: Rectangle {
            id: devCard
            width: ListView.view.width
            property bool isExpanded: btModule.stateMap[modelData.mac] ? btModule.stateMap[modelData.mac].isExpanded : false

            // Strict battery resolution: ONLY show battery when device is CONNECTED. Disconnected devices NEVER show battery!
            property string batteryLvl: {
                if (!modelData.connected) return "";
                if (typeof dashMod !== "undefined" && dashMod.btConnectedMac === modelData.mac && dashMod.btIslandBattery !== "") {
                    return dashMod.btIslandBattery;
                }
                return btModule.batteryMap[modelData.mac] || "";
            }
            property int batteryPct: batteryLvl !== "" ? parseInt(batteryLvl) : -1

            // Dynamic height (50px collapsed, 92px expanded with drawer)
            height: isExpanded ? 92 : 50
            radius: 12
            color: cardHover.containsMouse ? btModule.colCardHover : btModule.colCard
            border.width: 0
            clip: true

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

            MouseArea {
                id: cardHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btModule.toggleExpand(modelData.mac)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Top Primary Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Squircle Icon Badge
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        color: modelData.connected ? Qt.alpha(btModule.colAccent, 0.22) : btModule.colChipBg
                        border.width: 0

                        Text {
                            anchors.centerIn: parent
                            text: btModule.iconFor(modelData)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: modelData.connected ? btModule.colAccent : btModule.colSubtext
                        }
                    }

                    // Device Name & Status Chips
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: modelData.name
                            color: modelData.connected ? btModule.colAccent : btModule.colText
                            font.family: "Noto Sans"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Row {
                            spacing: 5
                            Rectangle {
                                height: 16
                                radius: 8
                                color: modelData.connected ? Qt.alpha(btModule.colGreen, 0.2) : btModule.colChipBg
                                border.width: 0
                                implicitWidth: statusChipRow.implicitWidth + 10

                                Row {
                                    id: statusChipRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Rectangle {
                                        visible: modelData.connected
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: btModule.colGreen
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                                        font.family: "Noto Sans"
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        renderType: Text.NativeRendering
                                        color: modelData.connected ? btModule.colGreen : btModule.colSubtext
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // Battery Badge Pill (Visible only if connected and battery reported)
                    Rectangle {
                        visible: modelData.connected && devCard.batteryLvl !== ""
                        height: 22
                        radius: 7
                        color: (devCard.batteryPct >= 0 && devCard.batteryPct < 20) ? Qt.alpha(btModule.colRed, 0.22) : btModule.colChipBg
                        border.width: 0
                        implicitWidth: devBatRow.implicitWidth + 10

                        Row {
                            id: devBatRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: devCard.batteryLvl
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                color: (devCard.batteryPct >= 0 && devCard.batteryPct < 20) ? btModule.colRed : btModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: btModule.batteryIconFor(devCard.batteryPct)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: (devCard.batteryPct >= 0 && devCard.batteryPct < 20) ? btModule.colRed : btModule.colAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Expand Caret Icon
                    Text {
                        text: devCard.isExpanded ? "󰅃" : "󰅀"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: btModule.colMuted
                    }
                }

                // Drawer Action Row (Solid buttons, Zero borders)
                RowLayout {
                    Layout.fillWidth: true
                    visible: devCard.isExpanded
                    spacing: 6

                    // Connect / Disconnect Action Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 8
                        color: modelData.connected ? Qt.alpha(btModule.colRed, 0.24) : btModule.colAccent
                        border.width: 0

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: modelData.connected ? "󰂲" : "󰂱"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: modelData.connected ? btModule.colRed : btModule.colSurface
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.connected ? "Disconnect" : "Connect"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                color: modelData.connected ? btModule.colRed : btModule.colSurface
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.connected) {
                                    modelData.device.disconnect();
                                } else {
                                    modelData.device.connect();
                                }
                            }
                        }
                    }

                    // Forget Device Button
                    Rectangle {
                        Layout.preferredWidth: 80
                        height: 28
                        radius: 8
                        color: btModule.colChipBg
                        border.width: 0

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "󰆴"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: btModule.colSubtext
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Forget"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                                color: btModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bluetoothctl", "remove", modelData.mac]);
                            }
                        }
                    }

                    // MAC Pill
                    Rectangle {
                        Layout.preferredWidth: 120
                        height: 28
                        radius: 8
                        color: btModule.colChipBg
                        border.width: 0

                        Text {
                            anchors.centerIn: parent
                            text: modelData.mac
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: btModule.colSubtext
                        }
                    }
                }
            }
        }
    }
}
