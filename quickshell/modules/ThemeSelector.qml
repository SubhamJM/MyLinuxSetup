import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: themeSelector
    spacing: 12

    property alias themeList: themeList
    ListModel { id: themeModel }

    Process {
        id: themeScanner
        running: root.activeMode === "theme"
        command: ["sh", "-c", `python3 -c "import os; d=os.path.expanduser('~/.config/themes'); print('\\n'.join(sorted(os.listdir(d))) if os.path.exists(d) else '')"`]
        stdout: StdioCollector {
            onStreamFinished: {
                themeModel.clear();
                var lines = this.text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim() !== "") themeModel.append({"themeName": lines[i].trim()});
                }
            }
        }
    }

    Process {
        id: themeRunner
        running: false
        onExited: Theme.reload()
    }

    Text {
        text: "Themes"
        font.pixelSize: 16
        font.bold: true
        color: Theme.colors.text_primary ?? "white"
        Layout.alignment: Qt.AlignHCenter
    }

    GridView {
        id: themeList
        focus: true
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: width / 2
        cellHeight: 45
        model: themeModel

        Keys.onEscapePressed: root.activeMode = "idle"
        Keys.onLeftPressed: if (currentIndex > 0) currentIndex--
        Keys.onRightPressed: if (currentIndex < count - 1) currentIndex++
        Keys.onUpPressed: if (currentIndex - 2 >= 0) currentIndex -= 2
        Keys.onDownPressed: if (currentIndex + 2 < count) currentIndex += 2
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

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: isSelected ? (Theme.colors.hover_bg ?? "#24283b") : (themeMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335"))
                border.color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (themeMouse.containsMouse ? (Theme.colors.border_hover ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e"))
                border.width: isSelected ? 2 : 1
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: themeName
                    color: isSelected || themeMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "white")
                    font.pixelSize: 14; font.bold: true
                }

                MouseArea {
                    id: themeMouse
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: themeList.currentIndex = index
                    onClicked: themeList.applyTheme(index)
                }
            }
        }
    }
}
