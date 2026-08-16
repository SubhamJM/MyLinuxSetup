import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../"

ColumnLayout {
    id: btModule
    spacing: 10
    
    property var stateMap: ({})

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

    // Current Connection Status (Dynamic Island style text block)
    Rectangle {
        Layout.fillWidth: true; height: 36; radius: 8
        color: Theme.colors.hover_bg ?? "#24283b"
        border.width: 1; border.color: Theme.colors.border ?? "#16161e"
        
        RowLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 8
            
            Text {
                text: (typeof dashMod !== "undefined" && dashMod.btConnected) ? "󰂱" : "󰂯"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                color: Theme.colors.accent ?? "#7aa2f7"
            }
            Text {
                Layout.fillWidth: true
                text: {
                    if (typeof dashMod === "undefined") return "Bluetooth status";
                    return dashMod.btConnected ? ("Bluetooth connected to " + dashMod.btDeviceName) : "Bluetooth disconnected";
                }
                font.pixelSize: 13; font.bold: true
                color: Theme.colors.text_primary ?? "white"
                elide: Text.ElideRight
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "Bluetooth Devices"
            font.pixelSize: 16
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
        }

        Item { Layout.fillWidth: true }
        
        Rectangle {
            width: 80; height: 28; radius: 8
            color: typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.card_bg ?? "#1f2335")
            Text {
                anchors.centerIn: parent
                text: typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? "Scanning..." : "Scan"
                color: typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                font.bold: true; font.pixelSize: 12
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
                        Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering;
                    }
                }
            }
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: btModule.filteredDevices

        Item {
            anchors.fill: parent
            visible: btModule.filteredDevices.length === 0
            Text {
                anchors.centerIn: parent
                text: typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? "Searching for devices..." : "No devices found"
                color: Theme.colors.text_secondary ?? "#565f89"
                font.pixelSize: 13
            }
        }

        delegate: Rectangle {
            id: btCard
            width: ListView.view.width
            property bool isExpanded: btModule.stateMap[modelData.mac] ? btModule.stateMap[modelData.mac].isExpanded : false
            property string batteryLvl: btModule.stateMap[modelData.mac] ? btModule.stateMap[modelData.mac].battery : ""
            
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
                    
                    Text {
                        text: modelData.connected ? "󰂱" : "󰂯"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                        color: modelData.connected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                    }
                    
                    Column {
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            spacing: 6
                            Text {
                                text: modelData.name
                                color: modelData.connected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "white")
                                font.pixelSize: 13; font.bold: true
                                elide: Text.ElideRight; Layout.maximumWidth: btCard.width - 150
                            }
                            Text { visible: batteryLvl !== ""; text: "• " + batteryLvl; font.pixelSize: 11; font.bold: true; color: Theme.colors.accent ?? "#7aa2f7" }
                        }
                        Text {
                            text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                            color: modelData.connected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                            font.pixelSize: 11
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
