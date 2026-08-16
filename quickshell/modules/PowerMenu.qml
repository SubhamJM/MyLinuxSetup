import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"

RowLayout {
    id: powerMenu
    anchors.fill: parent
    spacing: 12

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

    // Hold Button Component
    component HoldButton: Rectangle {
        id: btnRoot
        property int btnIndex: -1
        property bool isFocused: powerMenu.currentIndex === btnIndex
        property string iconText: ""
        property string actionCmd: ""
        property color iconColor: Theme.colors.text_primary ?? "#c0caf5"
        property color activeColor: Theme.colors.accent ?? "#7aa2f7"
        property real progress: 0.0

        Layout.preferredWidth: 54
        Layout.preferredHeight: 54
        Layout.alignment: Qt.AlignVCenter
        radius: 12
        color: holdMouse.containsMouse || isFocused ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335")
        border.width: 1
        border.color: holdMouse.pressed ? activeColor : ((holdMouse.containsMouse || isFocused) ? activeColor : (Theme.colors.border ?? "#16161e"))

        opacity: root.activeMode === "powermenu" ? 1.0 : 0.0
        transform: Translate {
            y: root.activeMode === "powermenu" ? 0 : 4
            Behavior on y { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }
        }
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

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

        // Circular Fill Ring
        Canvas {
            id: progressCanvas
            anchors.fill: parent
            anchors.margins: 3
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
                ctx.lineWidth = 3;
                ctx.strokeStyle = btnRoot.activeColor;
                ctx.lineCap = "round";
                ctx.stroke();
            }
        }

        // Action Icon
        Text {
            anchors.centerIn: parent
            text: btnRoot.iconText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22
            color: holdMouse.pressed || btnRoot.isFocused ? btnRoot.activeColor : btnRoot.iconColor
            scale: holdMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
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

    // 1. Lock Screen
    HoldButton {
        btnIndex: 0
        iconText: "󰌾"
        actionCmd: "pidof hyprlock || hyprlock || swaylock || loginctl lock-session"
        activeColor: Theme.colors.accent ?? "#7aa2f7"
    }

    // 2. Sleep / Suspend
    HoldButton {
        btnIndex: 1
        iconText: "󰒲"
        actionCmd: "systemctl suspend"
        activeColor: "#e0af68"
    }

    // 3. Logout
    HoldButton {
        btnIndex: 2
        iconText: "󰍃"
        actionCmd: "hyprctl dispatch exit || loginctl terminate-user $USER"
        activeColor: "#bb9af7"
    }

    // 4. Reboot
    HoldButton {
        btnIndex: 3
        iconText: "󰜉"
        actionCmd: "systemctl reboot"
        activeColor: "#7dcfff"
    }

    // 5. Power Off
    HoldButton {
        btnIndex: 4
        iconText: "󰐥"
        actionCmd: "systemctl poweroff"
        activeColor: "#f44336"
        iconColor: "#f44336"
    }
}
