import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: clipModule
    spacing: 10

    property alias searchInput: searchInput
    ListModel { id: clipModel }

    readonly property int calculatedCount: clipModel.count

    function refresh() {
        if (clipScanner.running) clipScanner.running = false;
        clipScanner.running = true;
    }

    // Refresh automatically whenever the clipboard notch mode is entered
    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode === "clipboard") {
                clipModule.refresh();
            }
        }
    }

    // Fallback refresh whenever visibility becomes active
    onVisibleChanged: {
        if (visible && root.activeMode === "clipboard") {
            clipModule.refresh();
        }
    }

    // Query past 100 clipboard entries and generate thumbnail images for binary entries
    Process {
        id: clipScanner
        running: false
        command: ["sh", "-c", `
            python3 -c "
import subprocess, os, re

try:
    thumb_dir = '/tmp/cliphist_thumbs'
    os.makedirs(thumb_dir, exist_ok=True)
    raw = subprocess.check_output(['cliphist', 'list'], text=True, errors='ignore').strip()
    lines = [l for l in raw.splitlines() if l.strip()][:100]
    
    out = []
    for line in lines:
        parts = line.split('\t', 1)
        if len(parts) < 2:
            continue
        c_id = parts[0].strip()
        c_desc = parts[1].strip()
        
        is_img = bool(re.search(r'\[\[\s*binary\s+data\s+.*\b(png|jpeg|jpg|webp|bmp|image)\b.*\]\]', c_desc, re.I))
        img_path = ''
        
        if is_img:
            img_path = f'{thumb_dir}/clip_{c_id}.png'
            if not os.path.exists(img_path):
                subprocess.run(f'cliphist decode {c_id} > {img_path}', shell=True)
        
        c_desc_clean = c_desc.replace('|||', ' ')
        out.append(f'{c_id}|||{is_img}|||{img_path}|||{c_desc_clean}')
    
    print('\\n'.join(out))
except Exception as e:
    pass
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                clipModel.clear();
                var lines = this.text.trim().split("\n");
                var query = searchInput.text.toLowerCase().trim();
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 4) {
                        var id = parts[0];
                        var isImage = (parts[1] === "True");
                        var imgPath = parts[2];
                        var desc = parts[3];

                        if (query === "" || desc.toLowerCase().includes(query)) {
                            clipModel.append({
                                "clipId": id,
                                "isImage": isImage,
                                "imgPath": imgPath,
                                "description": desc
                            });
                        }
                    }
                }
            }
        }
    }

    Process { id: clipPaster; running: false }

    function copyItemToTop(id) {
        if (clipPaster.running) clipPaster.running = false;
        clipPaster.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"];
        clipPaster.running = true;
        root.activeMode = "idle";
    }

    // Top Search & Clear Bar
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "󰅌"
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
            placeholderText: "Search clipboard history..."
            placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
            background: Item {}

            onTextChanged: clipModule.refresh()

            Keys.onDownPressed: if (clipList.currentIndex < clipModel.count - 1) clipList.currentIndex++
            Keys.onUpPressed: if (clipList.currentIndex > 0) clipList.currentIndex--
            Keys.onEscapePressed: root.activeMode = "idle"
            Keys.onReturnPressed: {
                if (clipModel.count > 0 && clipList.currentIndex >= 0) {
                    copyItemToTop(clipModel.get(clipList.currentIndex).clipId);
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 64
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
                    Quickshell.execDetached(["sh", "-c", "cliphist wipe && rm -rf /tmp/cliphist_thumbs/*"]);
                    clipModel.clear();
                    root.activeMode = "idle";
                }
            }
        }
    }

    // Clipboard Items List
    ListView {
        id: clipList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: clipModel
        currentIndex: 0

        Item {
            anchors.fill: parent
            visible: clipModel.count === 0
            Text {
                anchors.centerIn: parent
                text: "Clipboard history is empty"
                color: Theme.colors.text_secondary ?? "#565f89"
                font.pixelSize: 13
            }
        }

        delegate: Rectangle {
            width: ListView.view.width
            height: isImage ? 64 : 44
            property bool isSelected: ListView.isCurrentItem
            radius: 8
            color: isSelected ? (Theme.colors.hover_bg ?? "#24283b") : (clipMouse.containsMouse ? (Theme.colors.card_bg ?? "#1f2335") : "transparent")
            border.width: 1
            border.color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 10

                // Preview Thumbnail or Format Icon
                Item {
                    Layout.preferredWidth: isImage ? 52 : 28
                    Layout.preferredHeight: isImage ? 52 : 28
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Theme.colors.bg ?? "#16161e"
                        clip: true

                        Image {
                            anchors.fill: parent
                            visible: isImage && imgPath !== ""
                            source: imgPath !== "" ? "file://" + imgPath : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !isImage
                            text: "󰅍"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                        }
                    }
                }

                // Description Text
                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: isImage ? "[Image Preview]" : description
                    color: isSelected ? (Theme.colors.accent ?? "#ffffff") : (Theme.colors.text_primary ?? "#c0caf5")
                    font.pixelSize: 12
                    font.bold: isImage
                    elide: Text.ElideRight
                    maximumLineCount: isImage ? 1 : 2
                    wrapMode: Text.WrapAnywhere
                }

                // Copy Action Indicator
                Text {
                    text: "󰆏"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                    visible: isSelected || clipMouse.containsMouse
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            MouseArea {
                id: clipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: clipList.currentIndex = index
                onClicked: clipModule.copyItemToTop(clipId)
            }
        }
    }
}
