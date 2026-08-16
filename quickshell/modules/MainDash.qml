import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../"

Item {
    id: dash
    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitWidth: 560

    RowLayout {
        id: dashRow
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 0

        // Workspaces
        Row {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: 6
            opacity: root.activeMode === "hover" ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            Repeater {
                model: typeof Hyprland !== "undefined" && Hyprland.workspaces ? Hyprland.workspaces.values : []
                delegate: Rectangle {
                    width: 26; height: 26; radius: 8
                    property bool isFocused: typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && (modelData.id === Hyprland.focusedWorkspace.id)
                    color: isFocused ? (Theme.colors.accent ?? "#7aa2f7") : (wsMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent")
                    border.width: wsMouse.containsMouse && !isFocused ? 1 : 0
                    border.color: Theme.colors.border_hover ?? "#7aa2f7"
                    Behavior on color { ColorAnimation { duration: 80 } }

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

        Item { Layout.fillWidth: true; Layout.minimumWidth: 10 }

        // Date & Time + Recording Dot
        Rectangle {
            Layout.alignment: Qt.AlignCenter
            width: timeRow.implicitWidth + (root.isScreenRecording ? 32 : 24)
            implicitWidth: width
            height: 26
            radius: 8
            color: timeMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
            border.width: timeMouse.containsMouse ? 1 : 0
            border.color: Theme.colors.border_hover ?? "#7aa2f7"
            Behavior on color { ColorAnimation { duration: 80 } }

            Row {
                id: timeRow
                anchors.centerIn: parent
                spacing: 6

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

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 3.5
                    color: "#f44336"
                    visible: root.isScreenRecording

                    SequentialAnimation on opacity {
                        running: root.isScreenRecording
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.2; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.2; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
                }
            }
            MouseArea {
                id: timeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.isScreenRecording) root.switchMode("recorder");
                }
            }
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 10 }

        // System Tray & Actions
        Row {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: 6
            opacity: root.activeMode === "hover" ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

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

            Rectangle {
                width: 26; height: 26; radius: 8
                color: recMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: recMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Text {
                    anchors.centerIn: parent
                    text: "󰕧"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                    color: Theme.colors.text_primary ?? "#c0caf5"
                }
                MouseArea {
                    id: recMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("recorder")
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
					property int batteryLevel: typeof battMod !== "undefined" ? battMod.batteryLevel : 100
					property bool isCharging: typeof battMod !== "undefined" ? battMod.isCharging : false

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
				MouseArea { 
					id: battMouse
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: root.switchMode("battery")
				}
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
