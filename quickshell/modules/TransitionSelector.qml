import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: transModule
    spacing: 10
    Layout.fillWidth: true
    Layout.fillHeight: true

    property alias transitionGrid: transitionGrid

    readonly property var allTransitions: [
        { "name": "fade",    "label": "Fade",    "type": "fade" },
        { "name": "left",    "label": "Left",    "type": "left" },
        { "name": "right",   "label": "Right",   "type": "right" },
        { "name": "top",     "label": "Top",     "type": "top" },
        { "name": "bottom",  "label": "Bottom",  "type": "bottom" },
        { "name": "wipe",    "label": "Wipe",    "type": "wipe" },
        { "name": "wave",    "label": "Wave",    "type": "wave" },
        { "name": "outer",   "label": "Outer",   "type": "outer" },
        { "name": "random",  "label": "Random",  "type": "random" }
    ]

    ListModel { id: transitionModel }

    Component.onCompleted: {
        transitionModel.clear();
        for (var i = 0; i < allTransitions.length; i++) {
            transitionModel.append(allTransitions[i]);
        }
    }

    Process { 
        id: transitionWriter
        running: false
        onExited: Theme.reload()
    }

    // Header
    RowLayout {
        Layout.fillWidth: true
		Layout.preferredHeight: 24
		Layout.leftMargin: 8
        Layout.rightMargin: 8

        Text {
            text: "Wallpaper Transitions"
            font.family: "Inter"
            font.pixelSize: 15
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "Active: " + Theme.activeTransition
            font.family: "Inter"
            font.pixelSize: 11
            font.bold: true
            color: Theme.colors.accent ?? "#7aa2f7"
        }
    }

    // 3-Column Visual Grid
    GridView {
        id: transitionGrid
        focus: true
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: width / 3
        cellHeight: 76
        model: transitionModel

        boundsBehavior: Flickable.DragAndOvershootBounds

        Keys.onEscapePressed: root.activeMode = "idle"
        Keys.onLeftPressed: if (currentIndex > 0) currentIndex--
        Keys.onRightPressed: if (currentIndex < count - 1) currentIndex++
        Keys.onUpPressed: if (currentIndex - 3 >= 0) currentIndex -= 3
        Keys.onDownPressed: if (currentIndex + 3 < count) currentIndex += 3
        Keys.onReturnPressed: applyTransition(currentIndex)
        Keys.onEnterPressed: applyTransition(currentIndex)

        function applyTransition(idx) {
            if (idx >= 0 && idx < count) {
                var trans = transitionModel.get(idx).name;
                if (transitionWriter.running) transitionWriter.running = false;
                transitionWriter.command = [
                    "sh", "-c", 
                    "mkdir -p $HOME/.config/active-theme && echo -n '" + trans + "' > $HOME/.config/active-theme/wallpaper-transition.txt"
                ];
                transitionWriter.running = true;
                root.activeMode = "idle";
            }
        }

        delegate: Item {
            width: GridView.view.cellWidth
            height: GridView.view.cellHeight
            property bool isCurrent: name === Theme.activeTransition
            property bool isSelected: GridView.isCurrentItem

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 12
                color: isCurrent 
                    ? Qt.rgba((Theme.colors.accent ?? "#7aa2f7").r, (Theme.colors.accent ?? "#7aa2f7").g, (Theme.colors.accent ?? "#7aa2f7").b, 0.16)
                    : (transMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335"))
                
                border.width: isCurrent ? 2 : (isSelected ? 1.5 : (transMouse.containsMouse ? 1 : 0))
                border.color: isCurrent 
                    ? (Theme.colors.accent ?? "#7aa2f7") 
                    : (isSelected ? (Theme.colors.border_hover ?? "#7aa2f7") : Qt.rgba(1, 1, 1, 0.12))
                
                scale: transMouse.pressed ? 0.96 : (transMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    // Accurate Visual Canvas Icon
                    Canvas {
                        id: iconCanvas
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 20
                        renderTarget: Canvas.FramebufferObject

                        property color iconColor: isCurrent ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "white")
                        property color mutedColor: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.28)

                        onIconColorChanged: requestPaint()
                        Component.onCompleted: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var w = width, h = height;

                            // Outer viewport frame
                            ctx.strokeStyle = mutedColor;
                            ctx.lineWidth = 1.2;
                            ctx.strokeRect(1, 1, w - 2, h - 2);

                            ctx.fillStyle = iconColor;
                            ctx.strokeStyle = iconColor;
                            ctx.lineWidth = 1.6;
                            ctx.lineCap = "round";

                            
                            if (type === "fade") {
                                // Smooth Opacity Gradient
                                var grad = ctx.createLinearGradient(2, 0, w - 2, 0);
                                grad.addColorStop(0, "transparent");
                                grad.addColorStop(1, iconColor);
                                ctx.fillStyle = grad;
                                ctx.fillRect(2, 2, w - 4, h - 4);
                            }
                            else if (type === "left") {
                                // Slide Left Arrow
                                ctx.beginPath();
                                ctx.moveTo(w * 0.7, h * 0.5); ctx.lineTo(w * 0.3, h * 0.5);
                                ctx.moveTo(w * 0.45, h * 0.25); ctx.lineTo(w * 0.3, h * 0.5); ctx.lineTo(w * 0.45, h * 0.75);
                                ctx.stroke();
                            }
                            else if (type === "right") {
                                // Slide Right Arrow
                                ctx.beginPath();
                                ctx.moveTo(w * 0.3, h * 0.5); ctx.lineTo(w * 0.7, h * 0.5);
                                ctx.moveTo(w * 0.55, h * 0.25); ctx.lineTo(w * 0.7, h * 0.5); ctx.lineTo(w * 0.55, h * 0.75);
                                ctx.stroke();
                            }
                            else if (type === "top") {
                                // Slide Top Arrow
                                ctx.beginPath();
                                ctx.moveTo(w * 0.5, h * 0.75); ctx.lineTo(w * 0.5, h * 0.25);
                                ctx.moveTo(w * 0.35, h * 0.45); ctx.lineTo(w * 0.5, h * 0.25); ctx.lineTo(w * 0.65, h * 0.45);
                                ctx.stroke();
                            }
                            else if (type === "bottom") {
                                // Slide Bottom Arrow
                                ctx.beginPath();
                                ctx.moveTo(w * 0.5, h * 0.25); ctx.lineTo(w * 0.5, h * 0.75);
                                ctx.moveTo(w * 0.35, h * 0.55); ctx.lineTo(w * 0.5, h * 0.75); ctx.lineTo(w * 0.65, h * 0.55);
                                ctx.stroke();
                            }
                            else if (type === "wipe") {
                                // 45° Diagonal Wipe
                                ctx.beginPath();
                                ctx.moveTo(w * 0.75, 2);
                                ctx.lineTo(w * 0.25, h - 2);
                                ctx.stroke();

                                ctx.beginPath();
                                ctx.moveTo(2, 2);
                                ctx.lineTo(w * 0.75, 2);
                                ctx.lineTo(w * 0.25, h - 2);
                                ctx.lineTo(2, h - 2);
                                ctx.closePath();
                                ctx.fillStyle = Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.45);
                                ctx.fill();
                            }
                            else if (type === "wave") {
                                // Sine Wave Wipe Contour
                                ctx.beginPath();
                                ctx.moveTo(w * 0.5, 2);
                                ctx.bezierCurveTo(w * 0.75, h * 0.3, w * 0.25, h * 0.7, w * 0.5, h - 2);
                                ctx.stroke();

                                ctx.beginPath();
                                ctx.moveTo(2, 2);
                                ctx.lineTo(w * 0.5, 2);
                                ctx.bezierCurveTo(w * 0.75, h * 0.3, w * 0.25, h * 0.7, w * 0.5, h - 2);
                                ctx.lineTo(2, h - 2);
                                ctx.closePath();
                                ctx.fillStyle = Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.45);
                                ctx.fill();
                            }
                            else if (type === "outer") {
                                // Expanding Outer Circle Ripple
                                ctx.beginPath();
                                ctx.arc(w * 0.5, h * 0.5, h * 0.38, 0, 2 * Math.PI);
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.arc(w * 0.5, h * 0.5, h * 0.18, 0, 2 * Math.PI);
                                ctx.fill();
                            }
                            else if (type === "random") {
                                // Shuffle / Dice Vector
                                ctx.beginPath();
                                ctx.arc(w * 0.32, h * 0.35, 1.8, 0, 2 * Math.PI);
                                ctx.arc(w * 0.68, h * 0.35, 1.8, 0, 2 * Math.PI);
                                ctx.arc(w * 0.50, h * 0.50, 1.8, 0, 2 * Math.PI);
                                ctx.arc(w * 0.32, h * 0.65, 1.8, 0, 2 * Math.PI);
                                ctx.arc(w * 0.68, h * 0.65, 1.8, 0, 2 * Math.PI);
                                ctx.fill();
                            }
                        }
                    }

                    // Label
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: name
                        color: isCurrent ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "white")
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: isCurrent ? Font.Bold : Font.Medium
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: transMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: transitionGrid.currentIndex = index
                    onClicked: transitionGrid.applyTransition(index)
                }
            }
        }
    }
}
