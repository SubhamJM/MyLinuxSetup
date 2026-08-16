import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: launcher
    spacing: 10

    property alias searchInput: searchInput
    property var allApps: []
    ListModel { id: filteredAppModel }

    readonly property int calculatedCount: filteredAppModel.count

    function isSubsequence(query, target) {
        var qLen = query.length, tLen = target.length;
        if (qLen > tLen) return false;
        var qIdx = 0, tIdx = 0;
        while (qIdx < qLen && tIdx < tLen) {
            if (query[qIdx] === target[tIdx]) qIdx++;
            tIdx++;
        }
        return qIdx === qLen;
    }

    function updateList(filterText) {
        filteredAppModel.clear();
        var query = filterText.toLowerCase().trim();
        for (var i = 0; i < allApps.length; i++) {
            var app = allApps[i];
            if (query === "" || isSubsequence(query, app.name.toLowerCase())) {
                filteredAppModel.append(app);
            }
        }
    }

    Process {
        id: appScanner
        running: root.activeMode === "launcher"
        command: ["sh", "-c", `
            python3 -c "
import os, glob, re
apps = []
paths = ['/usr/share/applications', os.path.expanduser('~/.local/share/applications')]
for p in paths:
    for f in glob.glob(p + '/*.desktop'):
        try:
            with open(f, 'r', encoding='utf-8', errors='ignore') as file:
                content = file.read()
                if 'NoDisplay=true' in content: continue
                name = re.search(r'^Name=(.*)$', content, re.M)
                exec_cmd = re.search(r'^Exec=(.*)$', content, re.M)
                icon = re.search(r'^Icon=(.*)$', content, re.M)
                comment = re.search(r'^Comment=(.*)$', content, re.M)
                if name and exec_cmd and icon and icon.group(1).strip():
                    n = name.group(1).strip()
                    e = re.sub(r'%[fFuUiDc]', '', exec_cmd.group(1)).strip()
                    i = icon.group(1).strip()
                    c = comment.group(1).strip() if comment else ''
                    apps.append(f'{n}|||{e}|||{i}|||{c}')
        except: pass
print('\\n'.join(sorted(set(apps))))
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var tempList = [];
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 3) {
                        tempList.push({
                            "name": parts[0],
                            "exec": parts[1],
                            "iconName": parts[2],
                            "comment": parts.length > 3 ? parts[3] : ""
                        });
                    }
                }
                launcher.allApps = tempList;
                launcher.updateList(searchInput.text);
            }
        }
    }

    Process { id: appRunner; running: false }

    RowLayout {
        Layout.fillWidth: true
        spacing: 15

        Text {
            text: "⌕"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: Theme.colors.text_secondary ?? "#a9b1d6"
        }

        TextField {
            id: searchInput
            focus: true
            Layout.fillWidth: true
            color: Theme.colors.text_primary ?? "#c0caf5"
            font.pixelSize: 15
            placeholderText: "Search..."
            placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
            background: Item {}

            onTextChanged: launcher.updateList(text)

            Keys.onDownPressed: if (appList.currentIndex < filteredAppModel.count - 1) appList.currentIndex++
            Keys.onUpPressed:   if (appList.currentIndex > 0) appList.currentIndex--
            Keys.onEscapePressed: root.activeMode = "idle"

            onAccepted: {
                if (filteredAppModel.count > 0 && appList.currentIndex >= 0) {
                    var execCmd = filteredAppModel.get(appList.currentIndex).exec;
                    appRunner.command = ["sh", "-c", execCmd + " &"];
                    appRunner.running = true;
                } else if (text.trim() !== "") {
                    appRunner.command = ["sh", "-c", text.trim() + " &"];
                    appRunner.running = true;
                }
                root.activeMode = "idle";
            }
        }
    }

    ListView {
        id: appList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 4
        model: filteredAppModel
        currentIndex: 0

        delegate: Rectangle {
            width: ListView.view.width
            height: comment !== "" ? 50 : 38
            property bool isSelected: ListView.isCurrentItem
            property string appName: name
            property string appExec: exec
            color: isSelected ? (Theme.colors.hover_bg ?? "#24283b") : (appMouse.containsMouse ? (Theme.colors.card_bg ?? "#1f2335") : "transparent")
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                anchors.topMargin: 4;  anchors.bottomMargin: 4
                spacing: 12

                Item {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        source: {
                            if (iconName === "") return "";
                            if (iconName.startsWith("/")) return "file://" + iconName;
                            return "image://icon/" + iconName;
                        }
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: name
                        color: isSelected ? (Theme.colors.accent ?? "#ffffff") : (Theme.colors.text_primary ?? "#c0caf5")
                        font.pixelSize: 13; font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: comment !== "" ? comment : exec
                        color: isSelected ? (Theme.colors.text_primary ?? "#a9b1d6") : (Theme.colors.text_secondary ?? "#565f89")
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }
            }

            MouseArea {
				id: appMouse
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onEntered: appList.currentIndex = index
				onClicked: {
					appRunner.command = ["sh", "-c", appExec + " &"];
					appRunner.running = true;
					root.activeMode = "idle";
				}
			}
        }
    }
}
