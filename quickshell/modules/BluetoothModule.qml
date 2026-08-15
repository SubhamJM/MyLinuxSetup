import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../"

ColumnLayout {
    id: btModule
    spacing: 10

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
            width: ListView.view.width
            height: 45
            radius: 8
            color: Theme.colors.card_bg ?? "#1f2335"
            border.width: 1
            border.color: modelData.connected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 10
                
                Text {
                    text: modelData.connected ? "󰂱" : "󰂯"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                    color: modelData.connected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                }
                
                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: modelData.name
                        color: Theme.colors.text_primary ?? "white"
                        font.pixelSize: 13; font.bold: true
                        elide: Text.ElideRight; width: parent.width
                    }
                    Text {
                        text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                        color: modelData.connected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    width: 76; height: 26; radius: 6
                    color: modelData.connected ? "#f44336" : (Theme.colors.hover_bg ?? "#24283b")
                    Text {
                        anchors.centerIn: parent
                        text: modelData.connected ? "Disconnect" : "Connect"
                        color: "white"
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
            }
        }
    }
}
