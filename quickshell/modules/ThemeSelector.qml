import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: themeSelector
    spacing: 10
    Layout.fillWidth: true
    Layout.fillHeight: true

    property alias themeList: themeList
    ListModel { id: themeModel }

    // Scans all themes in ~/.config/themes and extracts bg, accent, and text colors
    Process {
        id: themeScanner
        running: root.activeMode === "theme"
        command: ["sh", "-c", `
            python3 -c "
import os, json, glob

theme_dir = os.path.expanduser('~/.config/themes')
if not os.path.exists(theme_dir):
    exit()

themes = sorted(os.listdir(theme_dir))
for t in themes:
    p = os.path.join(theme_dir, t)
    if not os.path.isdir(p):
        continue

    bg = '#1f2335'
    accent = '#7aa2f7'
    text = '#c0caf5'

    # Check for color definitions
    json_candidates = [
        os.path.join(p, 'quickshell-colors.json'),
        os.path.join(p, 'colors.json'),
        os.path.join(p, 'theme.json'),
        os.path.join(p, 'palette.json')
    ]

    for jc in json_candidates:
        if os.path.exists(jc):
            try:
                with open(jc, 'r') as f:
                    data = json.load(f)
                    bg = data.get('card_bg') or data.get('bg') or data.get('background') or bg
                    accent = data.get('accent') or data.get('primary') or data.get('color4') or accent
                    text = data.get('text_primary') or data.get('text') or data.get('foreground') or text
                    break
            except:
                pass

    print(f'{t}|||{bg}|||{accent}|||{text}')
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                themeModel.clear();
                var lines = this.text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 4) {
                        themeModel.append({
                            "themeName": parts[0].trim(),
                            "cardBg": parts[1].trim(),
                            "accentColor": parts[2].trim(),
                            "textColor": parts[3].trim()
                        });
                    }
                }
            }
        }
    }

    Process {
        id: themeRunner
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
            text: "Theme"
            font.family: "Inter"
            font.pixelSize: 15
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
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

    // 3-Column Preview Grid
    GridView {
        id: themeList
        focus: true
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: width / 3
        cellHeight: 74
        model: themeModel

        boundsBehavior: Flickable.DragAndOvershootBounds

        Keys.onEscapePressed: root.activeMode = "idle"
        Keys.onLeftPressed: if (currentIndex > 0) currentIndex--
        Keys.onRightPressed: if (currentIndex < count - 1) currentIndex++
        Keys.onUpPressed: if (currentIndex - 3 >= 0) currentIndex -= 3
        Keys.onDownPressed: if (currentIndex + 3 < count) currentIndex += 3
        Keys.onReturnPressed: applyTheme(currentIndex)
        Keys.onEnterPressed: applyTheme(currentIndex)

        function applyTheme(idx) {
            if (idx >= 0 && idx < count) {
                var name = themeModel.get(idx).themeName;
                if (themeRunner.running) themeRunner.running = false;
                themeRunner.command = ["sh", "-c", "~/.config/scripts/apply-theme.sh " + name];
                themeRunner.running = true;
                root.activeMode = "idle";
            }
        }

        delegate: Item {
            width: GridView.view.cellWidth
            height: GridView.view.cellHeight
            property bool isSelected: GridView.isCurrentItem
            property bool isCurrentActive: themeName.toLowerCase() === Theme.currentThemeName.toLowerCase()

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 12
                color: cardBg

                // Active / Hovered / Focused ring
                border.width: isCurrentActive ? 2 : (isSelected ? 1.5 : (themeMouse.containsMouse ? 1 : 0))
                border.color: isCurrentActive ? accentColor : (isSelected ? (Theme.colors.border_hover ?? "#7aa2f7") : Qt.rgba(1, 1, 1, 0.15))
                
                scale: themeMouse.pressed ? 0.96 : (themeMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    // Theme Accent Pill Capsule
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 7
                        radius: 3.5
                        color: accentColor
                    }

                    // Theme Name Label
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: themeName
                        color: textColor
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: isCurrentActive ? Font.Bold : Font.Medium
                        elide: Text.ElideRight
                        Layout.maximumWidth: parent.parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    id: themeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: themeList.currentIndex = index
                    onClicked: themeList.applyTheme(index)
                }
            }
        }
    }
}
