import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: wallModule
    spacing: 10

    property alias wallpaperGrid: wallpaperCarousel
    property string lastAppliedWallpaper: ""
    ListModel { id: wallpaperModel }

    // Query active wallpaper and populate carousel whenever the module opens
    Process {
        id: wallpaperScanner
        running: root.activeMode === "wallpaper"
        command: ["sh", "-c", `python3 -c "
import os, glob, subprocess

theme = '${Theme.currentThemeName}'
wall_dir = os.path.expanduser(f'~/Pictures/Wallpapers/{theme}')

# Get current active wallpaper path from awww query
active_wall = ''
try:
    p = subprocess.run(['awww', 'query'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    for line in p.stdout.splitlines():
        if 'image:' in line.lower():
            active_wall = line.split('image:', 1)[1].strip()
            break
        elif line.strip():
            active_wall = line.strip().split()[-1]
            break
except Exception:
    pass

exts = ('*.jpg', '*.jpeg', '*.png', '*.webp')
files = []
if os.path.exists(wall_dir):
    for ext in exts:
        files.extend(glob.glob(os.path.join(wall_dir, ext)))
    files.extend(glob.glob(os.path.join(wall_dir, '*/*.jpg')))
    files.extend(glob.glob(os.path.join(wall_dir, '*/*.png')))

sorted_files = sorted(list(set(files)))
for f in sorted_files:
    name = os.path.basename(f)
    print(f'{name}|||{f}|||{active_wall}')
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var temp = [];
                var activeFromQuery = "";

                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 2) {
                        temp.push({
                            "fileName": parts[0],
                            "filePath": parts[1]
                        });
                        if (parts.length >= 3 && parts[2].trim() !== "") {
                            activeFromQuery = parts[2].trim();
                        }
                    }
                }

                if (activeFromQuery !== "") {
                    wallModule.lastAppliedWallpaper = activeFromQuery;
                }

                // Snap smoothly without initial jump
                wallpaperCarousel.highlightMoveDuration = 0;

                wallpaperModel.clear();
                for (var j = 0; j < temp.length; j++) {
                    wallpaperModel.append(temp[j]);
                }
                
                var targetIdx = 0;
                if (wallModule.lastAppliedWallpaper !== "") {
                    for (var k = 0; k < wallpaperModel.count; k++) {
                        var fPath = wallpaperModel.get(k).filePath;
                        if (fPath === wallModule.lastAppliedWallpaper || wallModule.lastAppliedWallpaper.endsWith(wallpaperModel.get(k).fileName)) {
                            targetIdx = k;
                            break;
                        }
                    }
                }

                if (wallpaperModel.count > 0) {
                    wallpaperCarousel.currentIndex = targetIdx;
                    wallpaperCarousel.positionViewAtIndex(targetIdx, PathView.Center);
                }

                restoreAnimTimer.restart();
            }
        }
    }

    Timer {
        id: restoreAnimTimer
        interval: 60
        repeat: false
        onTriggered: wallpaperCarousel.highlightMoveDuration = 180
    }

    Process { id: wallpaperRunner; running: false }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 24
		spacing: 6
		Layout.leftMargin: 8
        Layout.rightMargin: 8

        Text {
            text: "Wallpapers"
            font.pixelSize: 15
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
        }

        Text {
            visible: wallpaperModel.count > 0
            text: "(" + (wallpaperCarousel.currentIndex + 1) + " / " + wallpaperModel.count + ")"
            font.pixelSize: 12
            font.bold: true
            color: Theme.colors.text_secondary ?? "#565f89"
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "Active: " + Theme.currentThemeName
            font.family: "Inter"
            font.pixelSize: 11
            font.bold: true
            color: Theme.colors.accent ?? "#7aa2f7"
        }
	}


    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent
            visible: wallpaperModel.count === 0
            text: "No wallpapers found in ~/Pictures/Wallpapers/" + Theme.currentThemeName
            color: Theme.colors.text_secondary ?? "#565f89"
            font.pixelSize: 13
        }

        RowLayout {
            anchors.fill: parent
            visible: wallpaperModel.count > 0
            spacing: 8

            Rectangle {
                id: leftArrow
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: leftArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: leftArrowMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Behavior on color { ColorAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅁"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                    color: leftArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                }
                MouseArea {
                    id: leftArrowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: wallpaperCarousel.decrementCurrentIndex()
                }
            }

            PathView {
                id: wallpaperCarousel
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true
                model: wallpaperModel

                pathItemCount: 5
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 0

                readonly property real itemWidth: Math.min(270, Math.max(160, width * 0.44))
                readonly property real itemHeight: height * 0.88

                Keys.onLeftPressed: decrementCurrentIndex()
                Keys.onRightPressed: incrementCurrentIndex()
                Keys.onReturnPressed: applySelected()
                Keys.onEnterPressed: applySelected()
                Keys.onEscapePressed: root.activeMode = "idle"

                function applySelected() {
                    wallModule.applyWallpaper(currentIndex);
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: Qt.PointingHandCursor
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        if (wheel.angleDelta.y < 0) wallpaperCarousel.incrementCurrentIndex();
                        else if (wheel.angleDelta.y > 0) wallpaperCarousel.decrementCurrentIndex();
                    }
                }

                path: Path {
                    startX: -wallpaperCarousel.itemWidth * 0.35
                    startY: wallpaperCarousel.height / 2
                    PathAttribute { name: "itemScale"; value: 0.55 }
                    PathAttribute { name: "itemOpacity"; value: 0.0 }
                    PathAttribute { name: "itemZ"; value: 1 }
                    PathAttribute { name: "itemRotationY"; value: -42.0 }

                    PathLine {
                        x: wallpaperCarousel.width * 0.22
                        y: wallpaperCarousel.height / 2
                    }
                    PathAttribute { name: "itemScale"; value: 0.80 }
                    PathAttribute { name: "itemOpacity"; value: 0.65 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemRotationY"; value: -28.0 }

                    PathLine {
                        x: wallpaperCarousel.width * 0.50
                        y: wallpaperCarousel.height / 2
                    }
                    PathAttribute { name: "itemScale"; value: 1.0 }
                    PathAttribute { name: "itemOpacity"; value: 1.0 }
                    PathAttribute { name: "itemZ"; value: 30 }
                    PathAttribute { name: "itemRotationY"; value: 0.0 }

                    PathLine {
                        x: wallpaperCarousel.width * 0.78
                        y: wallpaperCarousel.height / 2
                    }
                    PathAttribute { name: "itemScale"; value: 0.80 }
                    PathAttribute { name: "itemOpacity"; value: 0.65 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemRotationY"; value: 28.0 }

                    PathLine {
                        x: wallpaperCarousel.width + (wallpaperCarousel.itemWidth * 0.35)
                        y: wallpaperCarousel.height / 2
                    }
                    PathAttribute { name: "itemScale"; value: 0.55 }
                    PathAttribute { name: "itemOpacity"; value: 0.0 }
                    PathAttribute { name: "itemZ"; value: 1 }
                    PathAttribute { name: "itemRotationY"; value: 42.0 }
                }

                delegate: Item {
                    id: delegateRoot
                    width: wallpaperCarousel.itemWidth
                    height: wallpaperCarousel.itemHeight

                    scale: PathView.itemScale ?? 0.8
                    opacity: PathView.itemOpacity ?? 0.0
                    z: PathView.itemZ ?? 1
                    visible: opacity > 0.01

                    transform: Rotation {
                        origin.x: delegateRoot.width / 2
                        origin.y: delegateRoot.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: PathView.itemRotationY ?? 0
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Theme.colors.card_bg ?? "#1f2335"
                        border.width: PathView.isCurrentItem ? 2 : 1
                        border.color: PathView.isCurrentItem ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: filePath ? ("file://" + filePath) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: false
                            sourceSize.width: 480
                            sourceSize.height: 300
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (PathView.isCurrentItem) {
                                wallpaperCarousel.applySelected();
                            } else {
                                wallpaperCarousel.currentIndex = index;
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: rightArrow
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: rightArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: rightArrowMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Behavior on color { ColorAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅂"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                    color: rightArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                }
                MouseArea {
                    id: rightArrowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: wallpaperCarousel.incrementCurrentIndex()
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "󰅁 󰅂 Navigate • ↵ Apply"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: Theme.colors.text_secondary ?? "#565f89"
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            Layout.preferredWidth: 120; Layout.preferredHeight: 28
            radius: 8
            color: applyMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.hover_bg ?? "#24283b")
            border.width: 1
            border.color: Theme.colors.border_hover ?? "#7aa2f7"
            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text: "Apply"
                font.bold: true; font.pixelSize: 12
                color: applyMouse.containsMouse ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
            }
            MouseArea {
                id: applyMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wallpaperModel.count > 0) wallpaperCarousel.applySelected();
                }
            }
        }
    }

    function applyWallpaper(idx) {
        if (idx >= 0 && idx < wallpaperModel.count) {
            var path = wallpaperModel.get(idx).filePath;
            wallModule.lastAppliedWallpaper = path;
            if (wallpaperRunner.running) wallpaperRunner.running = false;
            wallpaperRunner.command = [
                "awww", "img", path,
                "--transition-type", Theme.activeTransition,
                "--transition-fps", "144",
                "--transition-step", "240",
                "--transition-bezier", "0.25,0.1,0.25,1.0"
            ];
            wallpaperRunner.running = true;
            root.collapseToIdle();
        }
    }
}
