import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"

RowLayout {
    id: powerMenu
    anchors.fill: parent
    spacing: 16

    property int currentIndex: 1

    Keys.onLeftPressed: { currentIndex = (currentIndex - 1 + 5) % 5; }
    Keys.onRightPressed: { currentIndex = (currentIndex + 1) % 5; }
    Keys.onReturnPressed: { triggerSelected(); }
    Keys.onSpacePressed: { triggerSelected(); }

    function triggerSelected() {
        var cmds = [
            "pidof hyprlock || hyprlock || swaylock || loginctl lock-session",
            "systemctl suspend",
            "hyprctl dispatch exit || loginctl terminate-user $USER",
            "systemctl reboot",
            "systemctl poweroff"
        ];
        Quickshell.execDetached(["sh", "-c", cmds[currentIndex]]);
        root.activeMode = "idle";
    }

    // Hold Button Component — solid, filled Android-style circular tile with a label
    component HoldButton: Item {
        id: btnRoot
        property int btnIndex: -1
        property bool isFocused: powerMenu.currentIndex === btnIndex
        property string iconText: ""
        property string label: ""
        property string actionCmd: ""
        property color activeColor: Theme.colors.accent ?? "#7aa2f7"
        property real progress: 0.0

        // Caelestia-flavoured emphasized-decelerate curve — smooth, no bounce
        readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

        Layout.preferredWidth: 64
        Layout.preferredHeight: 80
        Layout.alignment: Qt.AlignVCenter

        opacity: root.activeMode === "powermenu" ? 1.0 : 0.0
        transform: Translate {
            y: root.activeMode === "powermenu" ? 0 : 6
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.BezierCurve; easing.bezierCurve: btnRoot.motionCurve } }
        }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.BezierCurve; easing.bezierCurve: btnRoot.motionCurve } }

        NumberAnimation on progress {
            id: chargeAnim
            from: 0.0
            to: 1.0
            duration: 500
            running: false
            onFinished: {
                if (btnRoot.progress >= 1.0) {
                    Quickshell.execDetached(["sh", "-c", btnRoot.actionCmd]);
                    root.activeMode = "idle";
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 7

            // Solid filled circular tile — Android "tonal button" style:
            // a solid color-tinted disc behind the icon instead of a bordered square card
            Rectangle {
                id: circleBg
                width: 56
                height: 56
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(
                    btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b,
                    holdMouse.pressed ? 0.38 : ((holdMouse.containsMouse || btnRoot.isFocused) ? 0.26 : 0.16)
                )
                scale: holdMouse.pressed ? 0.92 : (btnRoot.isFocused ? 1.05 : 1.0)

                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.BezierCurve; easing.bezierCurve: btnRoot.motionCurve } }

                // Faint Material-style track ring behind the progress arc
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: width / 2
                    color: "transparent"
                    border.width: 2.5
                    border.color: Qt.rgba(1, 1, 1, 0.07)
                }

                // Circular Fill Ring — hold to confirm
                Canvas {
                    id: progressCanvas
                    anchors.fill: parent
                    anchors.margins: -4
                    renderTarget: Canvas.FramebufferObject

                    Connections {
                        target: btnRoot
                        function onProgressChanged() { progressCanvas.requestPaint(); }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (btnRoot.progress <= 0) return;

                        var centerX = width / 2;
                        var centerY = height / 2;
                        var radius = Math.min(centerX, centerY) - 2;

                        ctx.beginPath();
                        ctx.arc(centerX, centerY, radius, -Math.PI / 2, (-Math.PI / 2) + (Math.PI * 2 * btnRoot.progress), false);
                        ctx.lineWidth = 3.5;
                        ctx.strokeStyle = btnRoot.activeColor;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }
                }

                // Solid keyboard-focus ring
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -5
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: btnRoot.activeColor
                    opacity: btnRoot.isFocused ? 0.85 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }

                // Action Icon
                Text {
                    anchors.centerIn: parent
                    text: btnRoot.iconText
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                    color: btnRoot.activeColor
                }

                MouseArea {
                    id: holdMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onPressed: {
                        btnRoot.progress = 0.0;
                        chargeAnim.restart();
                    }
                    onReleased: {
                        chargeAnim.stop();
                        btnRoot.progress = 0.0;
                    }
                    onCanceled: {
                        chargeAnim.stop();
                        btnRoot.progress = 0.0;
                    }
                }
            }

            // Label — Android quick-settings tiles always name the action
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: btnRoot.label
                font.family: "Inter"
                font.pixelSize: 11
                font.weight: btnRoot.isFocused ? Font.DemiBold : Font.Medium
                color: btnRoot.isFocused ? btnRoot.activeColor : (Theme.colors.text_secondary ?? "#8a8f9e")
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }
    }

    // 1. Lock Screen
    HoldButton {
        btnIndex: 0
        iconText: "󰌾"
        label: "Lock"
        actionCmd: "pidof hyprlock || hyprlock || swaylock || loginctl lock-session"
        activeColor: Theme.colors.accent ?? "#7aa2f7"
    }

    // 2. Sleep / Suspend
    HoldButton {
        btnIndex: 1
        iconText: "󰒲"
        label: "Sleep"
        actionCmd: "systemctl suspend"
        activeColor: "#e0af68"
    }

    // 3. Logout
    HoldButton {
        btnIndex: 2
        iconText: "󰍃"
        label: "Logout"
        actionCmd: "hyprctl dispatch exit || loginctl terminate-user $USER"
        activeColor: "#bb9af7"
    }

    // 4. Reboot
    HoldButton {
        btnIndex: 3
        iconText: "󰜉"
        label: "Reboot"
        actionCmd: "systemctl reboot"
        activeColor: "#7dcfff"
    }

    // 5. Power Off
    HoldButton {
        btnIndex: 4
        iconText: "󰐥"
        label: "Power Off"
        actionCmd: "systemctl poweroff"
        activeColor: "#f44336"
    }
}
