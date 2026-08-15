import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../"

Item {
    id: dash
    Layout.fillWidth: true
    Layout.fillHeight: true

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 0

        // Workspaces
        Row {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: 6
            visible: root.activeMode === "hover"
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Repeater {
                model: typeof Hyprland !== "undefined" && Hyprland.workspaces ? Hyprland.workspaces.values : []
                delegate: Rectangle {
                    width: 26; height: 26; radius: 8
                    property bool isFocused: typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && (modelData.id === Hyprland.focusedWorkspace.id)
                    color: isFocused ? (Theme.colors.accent ?? "#7aa2f7") : (wsMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent")
                    border.width: wsMouse.containsMouse && !isFocused ? 1 : 0
                    border.color: Theme.colors.border_hover ?? "#7aa2f7"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.id
                        color: parent.isFocused ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                        font.pixelSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof Hyprland !== "undefined") Hyprland.dispatch("workspace " + modelData.id);
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true; visible: root.activeMode === "hover" }

        // Date & Time
        Rectangle {
            Layout.alignment: Qt.AlignCenter
            width: timeRow.implicitWidth + 24
            height: 26
            radius: 8
            color: timeMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
            border.width: timeMouse.containsMouse ? 1 : 0
            border.color: Theme.colors.border_hover ?? "#7aa2f7"
            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                id: timeRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    color: Theme.colors.text_secondary ?? "#565f89"
                    font.pixelSize: 13
                    font.bold: true
                    visible: root.activeMode === "hover"
                }
                Text {
                    text: Qt.formatDateTime(clock.date, root.activeMode === "hover" ? "hh:mm AP" : "hh:mm")
                    color: Theme.colors.text_primary ?? "white"
                    font.pixelSize: 14
                    font.bold: true
                    renderType: Text.QtRendering
                }
            }
            MouseArea {
                id: timeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }

        Item { Layout.fillWidth: true; visible: root.activeMode === "hover" }

        // System Tray & Actions
        Row {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: 6
            visible: root.activeMode === "hover"
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle {
                width: 26; height: 26; radius: 8
                color: wifiMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: wifiMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Text {
                    anchors.centerIn: parent
                    text: "󰖩"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                    color: Theme.colors.text_primary ?? "#c0caf5"
                }
                MouseArea {
                    id: wifiMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("wifi")
                }
            }

            Rectangle {
                width: 26; height: 26; radius: 8
                color: btMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: btMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Text {
                    anchors.centerIn: parent
                    text: "󰂯"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                    color: Theme.colors.text_primary ?? "#c0caf5"
                }
                MouseArea {
                    id: btMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("bluetooth")
                }
            }

            // Battery
            Rectangle {
                width: battRow.implicitWidth + 16; height: 26; radius: 8
                color: battMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: battMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"

                Row {
                    id: battRow
                    anchors.centerIn: parent
                    spacing: 6
                    property int batteryLevel: 100
                    property bool isCharging: false

                    Timer {
                        interval: 5000; running: root.activeMode === "hover"; repeat: true; triggeredOnStart: true
                        onTriggered: {
                            var xhrCap = new XMLHttpRequest();
                            xhrCap.open("GET", "file:///sys/class/power_supply/BAT1/capacity", true);
                            xhrCap.onreadystatechange = function() { if (xhrCap.readyState === XMLHttpRequest.DONE) { var val = parseInt(xhrCap.responseText); if (!isNaN(val)) parent.batteryLevel = val; } }
                            xhrCap.send();

                            var xhrStat = new XMLHttpRequest();
                            xhrStat.open("GET", "file:///sys/class/power_supply/BAT1/status", true);
                            xhrStat.onreadystatechange = function() { if (xhrStat.readyState === XMLHttpRequest.DONE) { parent.isCharging = (xhrStat.responseText.trim() === "Charging"); } }
                            xhrStat.send();
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.isCharging ? "󰂄" : (parent.batteryLevel > 20 ? "󰁹" : "󰂃")
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                        color: parent.isCharging || parent.batteryLevel > 20 ? (Theme.colors.accent ?? "#7aa2f7") : "#f44336"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.batteryLevel + "%"
                        color: Theme.colors.text_primary ?? "white"
                        font.pixelSize: 12; font.bold: true; font.features: { "tnum": 1 }
                    }
                }
                MouseArea { id: battMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
            }

            Item {
                width: 12; height: 26
                Rectangle { anchors.centerIn: parent; width: 1; height: 14; color: Theme.colors.text_secondary ?? "#565f89"; opacity: 0.4 }
            }

            // Power Buttons
            Rectangle {
                width: 26; height: 26; radius: 8
                color: suspMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: suspMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Text { anchors.centerIn: parent; text: "󰒲"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: suspMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89") }
                MouseArea { id: suspMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["systemctl", "suspend"]) }
            }

            Rectangle {
                width: 26; height: 26; radius: 8
                color: rebtMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: rebtMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Text { anchors.centerIn: parent; text: "󰜉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: rebtMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89") }
                MouseArea { id: rebtMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["systemctl", "reboot"]) }
            }

            Rectangle {
                width: 26; height: 26; radius: 8
                color: shutMouse.containsMouse ? "#f44336" : "transparent"
                border.width: shutMouse.containsMouse ? 1 : 0
                border.color: "#f44336"
                Text { anchors.centerIn: parent; text: "󰐥"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: shutMouse.containsMouse ? "white" : (Theme.colors.text_secondary ?? "#565f89") }
                MouseArea { id: shutMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["systemctl", "poweroff"]) }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
