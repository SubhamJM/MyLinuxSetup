import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: wallModule
    spacing: 12

    property alias wallpaperGrid: wallpaperGrid
    ListModel { id: wallpaperModel }

    Process {
        id: wallpaperScanner
        running: root.activeMode === "wallpaper"
        command: ["sh", "-c", `python3 -c "
import os, glob
theme = '${Theme.currentThemeName}'
wall_dir = os.path.expanduser(f'~/Pictures/Wallpapers/{theme}')
exts = ('*.jpg', '*.jpeg', '*.png', '*.webp')
files = []
if os.path.exists(wall_dir):
    for ext in exts:
        files.extend(glob.glob(os.path.join(wall_dir, ext)))
    files.extend(glob.glob(os.path.join(wall_dir, '*/*.jpg')))
    files.extend(glob.glob(os.path.join(wall_dir, '*/*.png')))
for f in sorted(list(set(files))):
    name = os.path.basename(f)
    print(f'{name}|||{f}')
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                wallpaperModel.clear();
                var lines = this.text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 2) {
                        wallpaperModel.append({
                            "fileName": parts[0],
                            "filePath": parts[1]
                        });
                    }
                }
            }
        }
    }

    Process { id: wallpaperRunner; running: false }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "Wallpapers (" + Theme.currentThemeName + ")"
            font.pixelSize: 15; font.bold: true
            color: Theme.colors.text_primary ?? "white"
        }
        Item { Layout.fillWidth: true }
        Text {
            text: wallpaperModel.count + " items"
            font.pixelSize: 12
            color: Theme.colors.text_secondary ?? "#565f89"
        }
    }

    GridView {
        id: wallpaperGrid
        focus: true
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: width / 3
        cellHeight: 120
        model: wallpaperModel

        Keys.onEscapePressed: root.activeMode = "idle"
        Keys.onLeftPressed: if (currentIndex > 0) currentIndex--
        Keys.onRightPressed: if (currentIndex < count - 1) currentIndex++
        Keys.onUpPressed: if (currentIndex - 3 >= 0) currentIndex -= 3
        Keys.onDownPressed: if (currentIndex + 3 < count) currentIndex += 3
        Keys.onReturnPressed: applyWallpaper(currentIndex)
        Keys.onEnterPressed: applyWallpaper(currentIndex)

        function applyWallpaper(idx) {
            if (idx >= 0 && idx < count) {
                var path = wallpaperModel.get(idx).filePath;
                if (wallpaperRunner.running) wallpaperRunner.running = false;
                wallpaperRunner.command = [
                    "awww", "img", path,
                    "--transition-type", Theme.activeTransition,
                    "--transition-fps", "144",
                    "--transition-step", "240",
                    "--transition-bezier", "0.25,0.1,0.25,1.0"
                ];
                wallpaperRunner.running = true;
                root.activeMode = "idle";
            }
        }

        delegate: Item {
            width: GridView.view.cellWidth
            height: GridView.view.cellHeight
            property bool isSelected: GridView.isCurrentItem

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: isSelected ? (Theme.colors.hover_bg ?? "#24283b") : (wallMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335"))
                border.color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (wallMouse.containsMouse ? (Theme.colors.border_hover ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e"))
                border.width: isSelected ? 2 : 1
                radius: 8
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: "file://" + filePath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }

                MouseArea {
                    id: wallMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: wallpaperGrid.currentIndex = index
                    onClicked: wallpaperGrid.applyWallpaper(index)
                }
            }
        }
    }
}
