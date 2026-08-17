import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: shelfModule
    spacing: 10
    focus: true

    property alias searchInput: searchInput
    property var selectedPaths: ({})

    ListModel { id: shelfModel }

    readonly property int calculatedCount: shelfModel.count

    function forceShelfFocus() {
        searchInput.forceActiveFocus();
    }

    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    function refreshFilter() {
        var query = searchInput.text.toLowerCase().trim();
        for (var i = 0; i < shelfModel.count; i++) {
            var item = shelfModel.get(i);
            var visible = (query === "" || item.name.toLowerCase().includes(query));
            shelfModel.setProperty(i, "isVisible", visible);
        }
    }

    function addDroppedFiles(urls) {
        for (var i = 0; i < urls.length; i++) {
            var rawUrl = urls[i].toString();
            var localPath = decodeURIComponent(rawUrl.replace(/^file:\/\//, ""));
            var fileName = localPath.split("/").filter(Boolean).pop() || localPath;

            var exists = false;
            for (var j = 0; j < shelfModel.count; j++) {
                if (shelfModel.get(j).filePath === localPath) {
                    exists = true;
                    break;
                }
            }

            if (!exists) {
                shelfModel.append({
                    "name": fileName,
                    "filePath": localPath,
                    "fileUrl": rawUrl.startsWith("file://") ? rawUrl : ("file://" + localPath),
                    "isVisible": true
                });
            }
        }
    }

    function toggleSelect(path) {
        var map = Object.assign({}, shelfModule.selectedPaths);
        if (map[path]) {
            delete map[path];
        } else {
            map[path] = true;
        }
        shelfModule.selectedPaths = map;
    }

    function selectAll() {
        var map = {};
        for (var i = 0; i < shelfModel.count; i++) {
            var item = shelfModel.get(i);
            if (item.isVisible) {
                map[item.filePath] = true;
            }
        }
        shelfModule.selectedPaths = map;
    }

    function copySelectedAndClose() {
        var paths = Object.keys(shelfModule.selectedPaths);
        if (paths.length === 0) return;

        var uriList = paths.map(p => "file://" + p).join("\n");
        Quickshell.execDetached([
            "sh", "-c", 
            `printf "%s" '${uriList}' | wl-copy -t text/uri-list && printf "%s" '${paths.join("\n")}' | wl-copy --primary`
        ]);

        shelfModule.selectedPaths = ({});
        root.collapseToIdle();
    }

    // Top Search & Actions Bar
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "󰉍"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: Theme.colors.accent ?? "#7aa2f7"
        }

        TextField {
            id: searchInput
            focus: true
            Layout.fillWidth: true
            color: Theme.colors.text_primary ?? "#c0caf5"
            font.pixelSize: 13
            placeholderText: "Search dropped items..."
            placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
            background: Item {}

            onTextChanged: shelfModule.refreshFilter()

            Keys.onEscapePressed: (event) => {
                root.collapseToIdle();
                event.accepted = true;
            }
        }

        // Copy Selected Button
        Rectangle {
            visible: Object.keys(shelfModule.selectedPaths).length > 0
            Layout.preferredWidth: 80
            Layout.preferredHeight: 24
            radius: 6
            color: copyMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.accent ?? "#7aa2f7")
            border.width: 1
            border.color: Theme.colors.border_hover ?? "#7aa2f7"

            Text {
                anchors.centerIn: parent
                text: "Copy (" + Object.keys(shelfModule.selectedPaths).length + ")"
                font.pixelSize: 11
                font.bold: true
                color: copyMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.bg ?? "#16161e")
            }

            MouseArea {
                id: copyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: shelfModule.copySelectedAndClose()
            }
        }

        // Clear All Button
        Rectangle {
            Layout.preferredWidth: 54
            Layout.preferredHeight: 24
            radius: 6
            color: clearMouse.containsMouse ? "#f44336" : (Theme.colors.card_bg ?? "#1f2335")
            border.width: 1
            border.color: Theme.colors.border ?? "#16161e"

            Text {
                anchors.centerIn: parent
                text: "Clear"
                font.pixelSize: 11
                font.bold: true
                color: clearMouse.containsMouse ? "white" : (Theme.colors.text_secondary ?? "#565f89")
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    shelfModel.clear();
                    shelfModule.selectedPaths = ({});
                }
            }
        }
    }

    // Shelf Items List
    ListView {
        id: shelfList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: shelfModel

        Item {
            anchors.fill: parent
            visible: shelfModel.count === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰛄"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 32
                    color: Theme.colors.text_secondary ?? "#565f89"
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Drag & drop files or folders here"
                    color: Theme.colors.text_secondary ?? "#565f89"
                    font.pixelSize: 12
                }
            }
        }

        delegate: Rectangle {
            width: ListView.view.width
            height: isVisible ? 44 : 0
            visible: isVisible
            radius: 8
            
            property bool isSelected: !!shelfModule.selectedPaths[filePath]
            color: isSelected ? (Theme.colors.hover_bg ?? "#24283b") : (itemMouse.containsMouse ? (Theme.colors.card_bg ?? "#1f2335") : "transparent")
            border.width: 1
            border.color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: isSelected ? "󰄲" : "󰄱"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                }

                Text {
                    text: "󰈔"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: Theme.colors.accent ?? "#7aa2f7"
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: name
                        color: isSelected ? (Theme.colors.accent ?? "#ffffff") : (Theme.colors.text_primary ?? "#c0caf5")
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideMiddle
                        width: parent.width
                    }
                    Text {
                        text: filePath
                        color: Theme.colors.text_secondary ?? "#565f89"
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                        width: parent.width
                    }
                }

                Text {
                    text: "✕"
                    font.pixelSize: 11
                    color: Theme.colors.text_secondary ?? "#565f89"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var map = Object.assign({}, shelfModule.selectedPaths);
                            delete map[filePath];
                            shelfModule.selectedPaths = map;
                            shelfModel.remove(index);
                        }
                    }
                }
            }

            MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: shelfModule.toggleSelect(filePath)
            }
        }
    }
}
