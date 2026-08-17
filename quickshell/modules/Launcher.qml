import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: launcher
    spacing: 12

    property alias searchInput: searchInput
    property var allApps: []
    ListModel { id: filteredAppModel }

    readonly property int calculatedCount: filteredAppModel.count
    readonly property color accentColor: Theme.colors.accent ?? "#7aa2f7"

    // Caelestia-flavoured emphasized-decelerate curve
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    // Reset scroll to top when the launcher is opened
    onVisibleChanged: {
        if (visible) {
            appList.positionViewAtBeginning();
            appList.currentIndex = filteredAppModel.count > 0 ? 0 : -1;
        }
    }

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
        appList.currentIndex = filteredAppModel.count > 0 ? 0 : -1;
        appList.positionViewAtBeginning(); // Instantly snap to top when typing
    }

    function recordUsageAndLaunch(execCmd) {
        appRunner.command = ["sh", "-c", execCmd + " &"];
        appRunner.running = true;
        
        usageTracker.targetExec = execCmd;
        usageTracker.running = true;
        
        root.activeMode = "idle";
    }

    Process {
        id: usageTracker
        running: false
        property string targetExec: ""
        command: ["python3", "-c", `
import sys, os, json
f = os.path.expanduser('~/.cache/qs_app_usage.json')
d = {}
try:
    with open(f, 'r') as file: d = json.load(file)
except: pass
cmd = sys.argv[1]
d[cmd] = d.get(cmd, 0) + 1
with open(f, 'w') as file: json.dump(d, file)
        `, targetExec]
    }

    Process {
        id: appScanner
        running: root.activeMode === "launcher"
        command: ["sh", "-c", `
            python3 -c "
import os, glob, re, json
apps = []
usage = {}
try:
    with open(os.path.expanduser('~/.cache/qs_app_usage.json'), 'r') as f: usage = json.load(f)
except: pass

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
                    u = usage.get(e, 0)
                    apps.append((u, n, e, i, c))
        except: pass
apps = sorted(list(set(apps)), key=lambda x: (-x[0], x[1].lower()))
for a in apps: print(f'{a[1]}|||{a[2]}|||{a[3]}|||{a[4]}')
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

    Rectangle {
        id: searchBar
        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: height / 2
        color: Theme.colors.card_bg ?? "#1f2335"
        border.width: 1.5
        border.color: searchInput.activeFocus ? launcher.accentColor : "transparent"
        Behavior on border.color { ColorAnimation { duration: 180 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 10
            spacing: 10

            Text {
                text: "⌕"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 17
                color: searchInput.activeFocus ? launcher.accentColor : (Theme.colors.text_secondary ?? "#a9b1d6")
                Behavior on color { ColorAnimation { duration: 180 } }
            }

            TextField {
                id: searchInput
                focus: true
                selectByMouse: true
                Layout.fillWidth: true
                color: Theme.colors.text_primary ?? "#c0caf5"
                font.family: "Inter"
                font.pixelSize: 15
                placeholderText: "Search apps..."
                placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                background: Item {}

                onTextChanged: launcher.updateList(text)

                Keys.onDownPressed: if (appList.currentIndex < filteredAppModel.count - 1) appList.currentIndex++
                Keys.onUpPressed:   if (appList.currentIndex > 0) appList.currentIndex--
                Keys.onEscapePressed: root.activeMode = "idle"

                onAccepted: {
                    if (filteredAppModel.count > 0 && appList.currentIndex >= 0) {
                        launcher.recordUsageAndLaunch(filteredAppModel.get(appList.currentIndex).exec);
                    } else if (text.trim() !== "") {
                        appRunner.command = ["sh", "-c", text.trim() + " &"];
                        appRunner.running = true;
                        root.activeMode = "idle";
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                visible: searchInput.text.length > 0
                color: clearMouse.containsMouse ? (Theme.colors.hover_bg ?? "#2a2f45") : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    color: Theme.colors.text_secondary ?? "#565f89"
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                }
            }
        }
    }

    Text {
        Layout.leftMargin: 4
        visible: searchInput.text.trim() !== ""
        text: filteredAppModel.count + (filteredAppModel.count === 1 ? " result" : " results")
        font.family: "Inter"
        font.pixelSize: 11
        font.weight: Font.Medium
        color: Theme.colors.text_secondary ?? "#565f89"
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: appList
            anchors.fill: parent
            clip: true
            spacing: 4
            model: filteredAppModel
            currentIndex: 0
            
            // Added Android-style fluid scrolling physics
            boundsBehavior: Flickable.DragAndOvershootBounds
            maximumFlickVelocity: 3500
            flickDeceleration: 2200

            // Sleek, minimal rounded scrollbar
            ScrollBar.vertical: ScrollBar { 
                policy: ScrollBar.AsNeeded
                width: 4
                contentItem: Rectangle { 
                    radius: 2
                    color: Theme.colors.text_secondary ?? "#565f89"
                    opacity: 0.4 
                } 
            }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
            addDisplaced: Transition { NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }
            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
            displaced: Transition { NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }

            delegate: Rectangle {
                id: delegateRoot
                width: ListView.view.width
                height: comment !== "" ? 54 : 42
                property bool isSelected: ListView.isCurrentItem
                property string appName: name
                property string appExec: exec
                radius: 12
                color: isSelected
                    ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.18)
                    : (appMouse.containsMouse ? (Theme.colors.card_bg ?? "#1f2335") : "transparent")
                scale: appMouse.pressed ? 0.98 : 1.0

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.BezierCurve; easing.bezierCurve: launcher.motionCurve } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 12
                    anchors.topMargin: 4;  anchors.bottomMargin: 4
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        radius: 11
                        color: delegateRoot.isSelected
                            ? Qt.rgba(launcher.accentColor.r, launcher.accentColor.g, launcher.accentColor.b, 0.24)
                            : (Theme.colors.card_bg ?? "#1f2335")
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 6
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            // Optimization: Prevents high-res icons from causing lag when scrolling
                            sourceSize.width: 32
                            sourceSize.height: 32
                            
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
                            color: delegateRoot.isSelected ? launcher.accentColor : (Theme.colors.text_primary ?? "#c0caf5")
                            font.family: "Inter"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: comment !== "" ? comment : exec
                            color: delegateRoot.isSelected ? (Theme.colors.text_primary ?? "#a9b1d6") : (Theme.colors.text_secondary ?? "#565f89")
                            font.family: "Inter"
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
                    onClicked: launcher.recordUsageAndLaunch(appExec)
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: filteredAppModel.count === 0 && searchInput.text.trim() !== ""

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰍉"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 22
                color: Theme.colors.text_secondary ?? "#565f89"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No apps found"
                font.family: "Inter"
                font.pixelSize: 12
                color: Theme.colors.text_secondary ?? "#565f89"
            }
        }
    }
}