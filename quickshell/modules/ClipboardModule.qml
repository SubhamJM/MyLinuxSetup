import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: clipModule
    spacing: 10
    Layout.fillWidth: true
    Layout.fillHeight: true

    property alias searchInput: searchInput
    ListModel { id: clipModel }

    readonly property int calculatedCount: clipModel.count

    function refresh() {
        if (clipScanner.running) clipScanner.running = false;
        clipScanner.running = true;
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode === "clipboard") {
                clipModule.refresh();
            }
        }
    }

    onVisibleChanged: {
        if (visible && root.activeMode === "clipboard") {
            clipModule.refresh();
        }
    }

    Component.onCompleted: clipModule.refresh()

    Process {
        id: clipScanner
        running: false
        command: ["sh", "-c", `
            python3 -c "
import subprocess, os, re

thumb_dir = '/tmp/cliphist_thumbs'
os.makedirs(thumb_dir, exist_ok=True)

try:
    p = subprocess.run(['cliphist', 'list'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    raw = p.stdout.decode('utf-8', errors='ignore')
except Exception:
    raw = ''

lines = [l for l in raw.splitlines() if l.strip()][:60]

for line in lines:
    parts = line.split('\t', 1)
    if len(parts) < 2:
        continue
    c_id = parts[0].strip()
    c_desc = parts[1].strip()
    
    is_img = ('binary data' in c_desc.lower() or bool(re.search(r'\\b(png|jpe?g|webp|bmp|gif)\\b', c_desc, re.I)))
    img_path = ''
    
    if is_img:
        img_path = f'{thumb_dir}/clip_{c_id}.png'
        if not os.path.exists(img_path) or os.path.getsize(img_path) == 0:
            try:
                dec = subprocess.run(['cliphist', 'decode', c_id], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=0.5)
                if dec.stdout:
                    with open(img_path, 'wb') as f:
                        f.write(dec.stdout)
            except Exception:
                pass
        
        if not (os.path.exists(img_path) and os.path.getsize(img_path) > 0):
            img_path = ''

    clean_desc = c_desc.replace('|||', ' ')
    print(f'{c_id}|||{is_img}|||{img_path}|||{clean_desc}')
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                clipModel.clear();
                var textRaw = this.text ? this.text.trim() : "";
                if (!textRaw) return;

                var lines = textRaw.split("\n");
                var query = searchInput.text.toLowerCase().trim();

                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 4) {
                        var id = parts[0].trim();
                        var isImage = (parts[1].trim() === "True");
                        var imgPath = parts[2].trim();
                        var desc = parts[3].trim();

                        if (query === "" || desc.toLowerCase().includes(query) || (isImage && "image".includes(query))) {
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
        root.collapseToIdle();
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
            Keys.onEscapePressed: root.collapseToIdle()
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
            color: clearMouse.containsMouse ? (Theme.colors.error ?? "#f44336") : (Theme.colors.card_bg ?? "#1f2335")
            border.width: 1
            border.color: Theme.colors.border ?? "#16161e"
            Behavior on color { ColorAnimation { duration: 150 } }

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
                    root.collapseToIdle();
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

        boundsBehavior: Flickable.DragAndOvershootBounds

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
            id: clipCard
            width: ListView.view.width
            height: isImage ? 80 : 44
            property bool isSelected: ListView.isCurrentItem
            radius: 8
            color: isSelected ? (Theme.colors.hover_bg ?? "#24283b") : (clipMouse.containsMouse ? (Theme.colors.card_bg ?? "#1f2335") : "transparent")
            border.width: 1
            border.color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12

                // Preview Thumbnail or Format Icon
                Rectangle {
                    Layout.preferredWidth: isImage ? 90 : 28
                    Layout.preferredHeight: isImage ? 64 : 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: 6
                    color: Theme.colors.bg ?? "#16161e"
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        visible: isImage && imgPath !== ""
                        source: (isImage && imgPath !== "") ? ("file://" + imgPath) : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        sourceSize.width: 140
                        sourceSize.height: 100
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !isImage || imgPath === ""
                        text: isImage ? "󰋩" : "󰅍"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                    }
                }

                // Description Text
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: isImage ? "Image" : description
                        color: isSelected ? (Theme.colors.accent ?? "#ffffff") : (Theme.colors.text_primary ?? "#c0caf5")
                        font.pixelSize: 12
                        font.bold: isImage
                        elide: Text.ElideRight
                        maximumLineCount: isImage ? 1 : 2
                        wrapMode: Text.WrapAnywhere
                    }

                    Text {
                        visible: isImage
                        Layout.fillWidth: true
                        text: description
                        color: Theme.colors.text_secondary ?? "#565f89"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                // Copy Action Indicator
                Text {
                    text: "󰆏"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
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
