import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../"

ColumnLayout {
    id: btModule
    spacing: 10

    // NOTE: shell.qml reads btMod.filteredDevices and btMod.stateMap[mac].isExpanded
    // directly to compute the notch height for "bluetooth" mode. Keep these two
    // property names/shapes stable, and keep card heights at 48 / 84 (see delegate
    // below) so root.targetHeight's math in shell.qml still lines up.
    property var stateMap: ({})

    readonly property var adapter: typeof Bluetooth !== "undefined" ? Bluetooth.defaultAdapter : null
    readonly property bool isEnabled: adapter ? adapter.enabled : false
    readonly property bool isDiscovering: adapter ? adapter.discovering : false

    Process {
        id: btBatteryFetcher
        running: false
        property string targetMac: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var batMatch = this.text.trim().match(/Battery Percentage:\s*(?:0x[0-9a-fA-F]+\s*)?\(([^)]+)\)/);
                if (batMatch && batMatch[1]) {
                    var sm = Object.assign({}, btModule.stateMap);
                    if (sm[btBatteryFetcher.targetMac]) {
                        sm[btBatteryFetcher.targetMac].battery = batMatch[1] + "%";
                        btModule.stateMap = sm;
                    }
                }
            }
        }
    }

    function toggleExpand(mac) {
        var sm = Object.assign({}, btModule.stateMap);
        if (!sm[mac]) sm[mac] = { isExpanded: false, battery: "" };
        sm[mac].isExpanded = !sm[mac].isExpanded;
        btModule.stateMap = sm;

        if (sm[mac].isExpanded) {
            btBatteryFetcher.targetMac = mac;
            btBatteryFetcher.command = ["sh", "-c", "bluetoothctl info " + mac];
            btBatteryFetcher.running = true;
        }
    }

    // Picks a device icon glyph from name/icon hints (from the popup design)
    function iconFor(dev) {
        var icon = (dev.device && dev.device.icon) ? dev.device.icon : "";
        var name = dev.name.toLowerCase();
        if (icon.includes("audio") || name.includes("bud") || name.includes("pod") || name.includes("headphone")) return "󰋋";
        if (icon.includes("phone") || name.includes("phone")) return "󰄜";
        if (icon.includes("computer") || name.includes("mac")) return "󰌢";
        if (icon.includes("mouse") || name.includes("mouse")) return "󰍽";
        if (icon.includes("keyboard") || name.includes("key")) return "󰌌";
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

    readonly property var filteredDevices: {
        if (typeof Bluetooth === "undefined" || !Bluetooth.devices) return [];
        var rawList = Bluetooth.devices.values;
        var seenNames = {};
        var result = [];

        for (var i = 0; i < rawList.length; i++) {
            var dev = rawList[i];
            var devName = dev.name ? dev.name.trim() : "";
            if (devName === "") continue;
            var isMacFormat = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/.test(devName);

            if (!seenNames[devName]) {
                seenNames[devName] = true;
                result.push({
                    "device": dev,
                    "mac": dev.address || "",
                    "name": devName,
                    "isMac": isMacFormat,
                    "connected": dev.connected,
                    "paired": dev.paired
                });
            }
        }

        return result.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
    }

    // ==========================================
    // HEADER — status + enable/disable toggle
    // ==========================================
    Rectangle {
        Layout.fillWidth: true; height: 44; radius: 10
        color: Theme.colors.hover_bg ?? "#24283b"
        border.width: 1; border.color: Theme.colors.border ?? "#16161e"

        RowLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 10

            Rectangle {
                width: 28; height: 28; radius: 14
                color: btModule.isEnabled ? Qt.rgba(1,1,1,0.08) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: btModule.isEnabled ? "󰂯" : "󰂲"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                    color: Theme.colors.accent ?? "#7aa2f7"
                }
            }

            Text {
                Layout.fillWidth: true
                text: {
                    if (typeof dashMod !== "undefined" && dashMod.btConnected) return "Connected to " + dashMod.btDeviceName;
                    return btModule.isEnabled ? "Ready to connect" : "Bluetooth is off";
                }
                font.pixelSize: 13; font.bold: true
                color: Theme.colors.text_primary ?? "white"
                elide: Text.ElideRight
            }

            // Toggle switch
            Item {
                implicitWidth: 40; implicitHeight: 22
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: btModule.isEnabled ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.card_bg ?? "#1f2335")
                    border.width: btModule.isEnabled ? 0 : 1
                    border.color: Theme.colors.border ?? "#16161e"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 16; height: 16; radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        x: btModule.isEnabled ? parent.width - width - 3 : 3
                        color: btModule.isEnabled ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_secondary ?? "#565f89")
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (btModule.adapter) btModule.adapter.enabled = !btModule.adapter.enabled
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: btModule.isEnabled

        Text {
            text: "Bluetooth Devices"
            font.pixelSize: 16
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            width: 84; height: 28; radius: 8
            color: btModule.isDiscovering ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.card_bg ?? "#1f2335")
            border.width: 1; border.color: Theme.colors.border ?? "#16161e"

            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: "󰑓"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                    color: btModule.isDiscovering ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                    RotationAnimation on rotation {
                        running: btModule.isDiscovering
                        from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                    }
                }
                Text {
                    text: btModule.isDiscovering ? "Scanning" : "Scan"
                    color: btModule.isDiscovering ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                    font.bold: true; font.pixelSize: 12
                }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: if (btModule.adapter) btModule.adapter.discovering = !btModule.adapter.discovering
            }
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: btModule.isEnabled ? btModule.filteredDevices : []

        Item {
            anchors.fill: parent
            visible: !btModule.isEnabled || btModule.filteredDevices.length === 0
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: btModule.isEnabled ? "󰂯" : "󰂲"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 28
                    color: Theme.colors.border ?? "#16161e"
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: !btModule.isEnabled ? "Bluetooth is disabled"
                        : (btModule.isDiscovering ? "Searching for devices..." : "No devices found")
                    color: Theme.colors.text_secondary ?? "#565f89"
                    font.pixelSize: 13
                }
            }
        }

        delegate: Rectangle {
            id: btCard
            width: ListView.view.width
            property bool isExpanded: btModule.stateMap[modelData.mac] ? btModule.stateMap[modelData.mac].isExpanded : false
            property string batteryLvl: btModule.stateMap[modelData.mac] ? btModule.stateMap[modelData.mac].battery : ""
            property int batteryPct: batteryLvl !== "" ? parseInt(batteryLvl) : -1

            // Keep these exact values — shell.qml's targetHeight math for "bluetooth"
            // mode assumes 48 collapsed / 84 expanded per card.
            height: isExpanded ? 84 : 48
            radius: 8
            color: Theme.colors.card_bg ?? "#1f2335"
            border.width: 1
            border.color: modelData.connected ? (Theme.colors.accent ?? "#7aa2f7") : (isExpanded ? (Theme.colors.border_hover ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e"))
            clip: true

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }

            MouseArea {
                anchors.fill: parent
                onClicked: btModule.toggleExpand(modelData.mac)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: modelData.connected ? Qt.rgba(1,1,1,0.08) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: btModule.iconFor(modelData)
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                            color: modelData.connected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: modelData.name
                            color: modelData.connected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "white")
                            font.pixelSize: 13; font.bold: true
                            elide: Text.ElideRight; width: btCard.width - 160
                        }
                        Text {
                            text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                            color: modelData.connected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                            font.pixelSize: 11
                        }
                    }

                    RowLayout {
                        visible: batteryLvl !== ""
                        spacing: 3
                        Text {
                            text: batteryLvl
                            font.pixelSize: 11; font.bold: true
                            color: (btCard.batteryPct >= 0 && btCard.batteryPct < 20) ? "#f44336" : (Theme.colors.accent ?? "#7aa2f7")
                        }
                        Text {
                            text: btModule.batteryIconFor(btCard.batteryPct)
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                            color: (btCard.batteryPct >= 0 && btCard.batteryPct < 20) ? "#f44336" : (Theme.colors.accent ?? "#7aa2f7")
                        }
                    }

                    Text { text: isExpanded ? "󰅃" : "󰅀"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Theme.colors.text_secondary ?? "#565f89" }
                }

                // Drawer Actions
                RowLayout {
                    Layout.fillWidth: true
                    visible: isExpanded
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 6
                        color: modelData.connected ? "#f44336" : (Theme.colors.accent ?? "#7aa2f7")
                        Text {
                            anchors.centerIn: parent
                            text: modelData.connected ? "Disconnect" : "Connect"
                            color: modelData.connected ? "white" : (Theme.colors.bg ?? "#16161e")
                            font.bold: true; font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.connected) {
                                    modelData.device.disconnect();
                                } else {
                                    modelData.device.connect();
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 6; color: Theme.colors.hover_bg ?? "#24283b"
                        border.width: 1; border.color: Theme.colors.border ?? "#16161e"
                        Text { anchors.centerIn: parent; text: "Forget"; color: Theme.colors.text_primary ?? "white"; font.bold: true; font.pixelSize: 11 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bluetoothctl", "remove", modelData.mac]);
                            }
                        }
                    }
                }
            }
        }
    }
}
