import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: shelfModule
    spacing: 8
    focus: true

    property alias searchInput: searchInput
    property var selectedPaths: ({})
    property int selectedCount: Object.keys(selectedPaths).length
    property int lastSelectedIndex: -1

    // Drag & Drop State
    property bool isDragging: dragProxy.Drag.active
    property string dragUriList: ""
    property var draggingPaths: []
    property string dragLabelText: ""

    // Marquee (Rubber-band) Selection State
    property bool isMarqueeActive: false
    property real marqueeStartX: 0
    property real marqueeStartY: 0
    property real marqueeCurrentX: 0
    property real marqueeCurrentY: 0
    property var marqueeBaseSelection: ({})

    ListModel { id: shelfModel }

    readonly property int calculatedCount: shelfModel.count

    function forceShelfFocus() {
        searchInput.forceActiveFocus();
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            shelfModule.selectAll();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (shelfModule.selectedCount > 0) {
                shelfModule.selectedPaths = ({});
                event.accepted = true;
            } else {
                root.collapseToIdle();
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (shelfModule.selectedCount > 0) {
                shelfModule.copySelectedAndClose();
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            if (shelfModule.selectedCount > 0) {
                shelfModule.removeSelected();
                event.accepted = true;
            }
        }
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

    function getFileIcon(name, path) {
        var lower = name.toLowerCase();
        if (lower.endsWith("/")) return "󰉋";
        var parts = lower.split(".");
        var ext = parts.length > 1 ? parts.pop() : "";
        switch (ext) {
            case "png": case "jpg": case "jpeg": case "webp": case "svg": case "gif": case "bmp":
                return "󰈟";
            case "mp4": case "mkv": case "mov": case "avi": case "webm":
                return "󰕧";
            case "mp3": case "flac": case "wav": case "ogg": case "m4a":
                return "󰎆";
            case "zip": case "tar": case "gz": case "xz": case "7z": case "rar":
                return "󰛫";
            case "pdf": case "txt": case "md": case "doc": case "docx": case "odt":
                return "󰈙";
            case "qml": case "js": case "ts": case "py": case "sh": case "rs": case "cpp": case "c": case "json":
                return "󰅩";
            default:
                return "󰈔";
        }
    }

    function toggleSelect(path, index) {
        var map = Object.assign({}, shelfModule.selectedPaths);
        if (map[path]) {
            delete map[path];
        } else {
            map[path] = true;
        }
        shelfModule.selectedPaths = map;
        shelfModule.lastSelectedIndex = index;
    }

    function selectRange(toIndex) {
        if (lastSelectedIndex === -1 || lastSelectedIndex >= shelfModel.count) {
            lastSelectedIndex = toIndex;
        }
        var from = Math.min(lastSelectedIndex, toIndex);
        var to = Math.max(lastSelectedIndex, toIndex);
        var map = Object.assign({}, selectedPaths);
        for (var i = from; i <= to; i++) {
            var item = shelfModel.get(i);
            if (item && item.isVisible) {
                map[item.filePath] = true;
            }
        }
        selectedPaths = map;
    }

    function selectAll() {
        var map = {};
        for (var i = 0; i < shelfModel.count; i++) {
            var item = shelfModel.get(i);
            if (item.isVisible) {
                map[item.filePath] = true;
            }
        }
        selectedPaths = map;
    }

    function toggleSelectAll() {
        if (selectedCount > 0) {
            selectedPaths = ({});
        } else {
            selectAll();
        }
    }

    function removeSelected() {
        var paths = Object.keys(selectedPaths);
        for (var i = 0; i < paths.length; i++) {
            for (var j = shelfModel.count - 1; j >= 0; j--) {
                if (shelfModel.get(j).filePath === paths[i]) {
                    shelfModel.remove(j);
                    break;
                }
            }
        }
        selectedPaths = ({});
    }

    function copySelectedAndClose() {
        var paths = Object.keys(shelfModule.selectedPaths);
        if (paths.length === 0) return;

        var uriList = paths.map(function(p) {
            return p.startsWith("file://") ? p : ("file://" + encodeURI(p));
        }).join("\n");

        Quickshell.execDetached([
            "sh", "-c", 
            `printf "%s" '${uriList}' | wl-copy -t text/uri-list && printf "%s" '${paths.join("\n")}' | wl-copy --primary`
        ]);

        shelfModule.selectedPaths = ({});
        root.collapseToIdle();
    }

    // Prepare files for dragging
    function prepareDragFor(filePath, index, modifiers) {
        if (modifiers & Qt.ShiftModifier) {
            selectRange(index);
            return;
        }
        if (modifiers & Qt.ControlModifier) {
            toggleSelect(filePath, index);
            return;
        }

        // If not already selected, select this one
        if (!selectedPaths[filePath]) {
            var map = {};
            map[filePath] = true;
            selectedPaths = map;
            lastSelectedIndex = index;
        }

        // Build dragged files list
        var paths = Object.keys(selectedPaths);
        if (paths.length === 0) {
            paths = [filePath];
        }
        draggingPaths = paths;

        // Build standard text/uri-list
        var uris = paths.map(function(p) {
            return p.startsWith("file://") ? p : ("file://" + encodeURI(p));
        });
        dragUriList = uris.join("\r\n") + "\r\n";

        if (paths.length === 1) {
            var name = paths[0].split("/").filter(Boolean).pop() || paths[0];
            dragLabelText = name;
        } else {
            dragLabelText = paths.length + " files";
        }
    }

    function handleItemClick(filePath, index, modifiers) {
        if (modifiers & Qt.ShiftModifier) {
            selectRange(index);
            return;
        }
        if (modifiers & Qt.ControlModifier) {
            toggleSelect(filePath, index);
            return;
        }
        var paths = Object.keys(selectedPaths);
        if (paths.length > 1) {
            var map = {};
            map[filePath] = true;
            selectedPaths = map;
            lastSelectedIndex = index;
        } else if (paths.length === 1 && selectedPaths[filePath]) {
            selectedPaths = ({});
            lastSelectedIndex = -1;
        } else {
            var map = {};
            map[filePath] = true;
            selectedPaths = map;
            lastSelectedIndex = index;
        }
    }

    function handleDragCompleted(dropAction) {
        shelfModule.isDragging = false;
        // If the drop was accepted by destination (non-ignore)
        if (dropAction !== Qt.IgnoreAction) {
            for (var i = 0; i < draggingPaths.length; i++) {
                var p = draggingPaths[i];
                for (var j = shelfModel.count - 1; j >= 0; j--) {
                    if (shelfModel.get(j).filePath === p) {
                        shelfModel.remove(j);
                        break;
                    }
                }
            }
            shelfModule.selectedPaths = ({});
            shelfModule.draggingPaths = [];
            // Automatically collapse notch to idle
            root.collapseToIdle();
        } else {
            shelfModule.draggingPaths = [];
        }
    }

    // Marquee Selection Logic
    function startMarquee(startX, startY, modifiers) {
        isMarqueeActive = true;
        marqueeStartX = startX;
        marqueeStartY = startY;
        marqueeCurrentX = startX;
        marqueeCurrentY = startY;
        marqueeBaseSelection = (modifiers & (Qt.ShiftModifier | Qt.ControlModifier)) ? Object.assign({}, selectedPaths) : {};
    }

    function updateMarquee(currentX, currentY) {
        marqueeCurrentX = currentX;
        marqueeCurrentY = currentY;

        var boxTop = Math.min(marqueeStartY, marqueeCurrentY);
        var boxBottom = Math.max(marqueeStartY, marqueeCurrentY);

        var map = Object.assign({}, marqueeBaseSelection);
        var rowHeight = 44;
        var rowSpacing = 6;
        var itemStride = rowHeight + rowSpacing;
        var scrollY = shelfList.contentY;

        for (var i = 0; i < shelfModel.count; i++) {
            var item = shelfModel.get(i);
            if (!item.isVisible) continue;

            var rowTop = (i * itemStride) - scrollY;
            var rowBottom = rowTop + rowHeight;

            if (rowBottom >= boxTop && rowTop <= boxBottom) {
                map[item.filePath] = true;
            }
        }
        selectedPaths = map;
    }

    function finishMarquee() {
        isMarqueeActive = false;
        marqueeBaseSelection = ({});
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
            placeholderText: shelfModel.count > 0 ? "Search items... (Ctrl+A to select all)" : "Drop files or folders into the notch..."
            placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
            background: Item {}

            onTextChanged: shelfModule.refreshFilter()

            Keys.onEscapePressed: (event) => {
                if (shelfModule.selectedCount > 0) {
                    shelfModule.selectedPaths = ({});
                    event.accepted = true;
                } else {
                    root.collapseToIdle();
                    event.accepted = true;
                }
            }
        }

        // Select All / Deselect Toggle
        Rectangle {
            visible: shelfModel.count > 0
            Layout.preferredWidth: selAllText.implicitWidth + 16
            Layout.preferredHeight: 24
            radius: 6
            color: selAllMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335")
            border.width: 1
            border.color: Theme.colors.border ?? "#16161e"

            Text {
                id: selAllText
                anchors.centerIn: parent
                text: shelfModule.selectedCount > 0 ? ("Deselect (" + shelfModule.selectedCount + ")") : "Select All"
                font.pixelSize: 11
                font.bold: true
                color: selAllMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
            }

            MouseArea {
                id: selAllMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: shelfModule.toggleSelectAll()
            }
        }

        // Copy Selected Button
        Rectangle {
            visible: shelfModule.selectedCount > 0
            Layout.preferredWidth: copyText.implicitWidth + 16
            Layout.preferredHeight: 24
            radius: 6
            color: copyMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.accent ?? "#7aa2f7")
            border.width: 1
            border.color: Theme.colors.border_hover ?? "#7aa2f7"

            Text {
                id: copyText
                anchors.centerIn: parent
                text: "Copy (" + shelfModule.selectedCount + ")"
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
            visible: shelfModel.count > 0
            Layout.preferredWidth: 48
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

    // Main Shelf List Area
    Item {
        id: listContainer
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        // Empty Background Area (for background click & drag marquee)
        MouseArea {
            id: bgMarqueeArea
            anchors.fill: parent
            z: 0
            onPressed: (mouse) => {
                shelfModule.startMarquee(mouse.x, mouse.y, mouse.modifiers);
            }
            onPositionChanged: (mouse) => {
                if (shelfModule.isMarqueeActive) {
                    shelfModule.updateMarquee(mouse.x, mouse.y);
                }
            }
            onReleased: (mouse) => {
                shelfModule.finishMarquee();
            }
        }

        // Empty State
        Item {
            anchors.fill: parent
            visible: shelfModel.count === 0
            z: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰉍"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 32
                    color: Theme.colors.text_secondary ?? "#565f89"
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Drop files or folders into the notch to stash them"
                    color: Theme.colors.text_primary ?? "#c0caf5"
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Drag files directly out into folders or browsers"
                    color: Theme.colors.text_secondary ?? "#565f89"
                    font.pixelSize: 11
                }
            }
        }

        // Shelf Items ListView
        ListView {
            id: shelfList
            anchors.fill: parent
            z: 2
            spacing: 6
            model: shelfModel
            boundsBehavior: Flickable.DragAndOvershootBounds
            interactive: !shelfModule.isDragging && !shelfModule.isMarqueeActive

            delegate: Rectangle {
                id: delegateRoot
                width: ListView.view.width
                height: isVisible ? 44 : 0
                visible: isVisible
                radius: 8
                
                property bool isSelected: !!shelfModule.selectedPaths[filePath]
                color: isSelected 
                    ? (Theme.colors.hover_bg ?? "#24283b") 
                    : (rowMouse.containsMouse || checkboxArea.containsMouse ? (Theme.colors.card_bg ?? "#1f2335") : "transparent")
                border.width: 1
                border.color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Checkbox & Touchpad Marquee Gutter
                    Item {
                        id: checkboxAreaItem
                        Layout.preferredWidth: 20
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            text: delegateRoot.isSelected ? "󰄲" : "󰄱"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: delegateRoot.isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                        }

                        MouseArea {
                            id: checkboxArea
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true

                            onPressed: (mouse) => {
                                var pos = mapToItem(listContainer, mouse.x, mouse.y);
                                shelfModule.startMarquee(pos.x, pos.y, mouse.modifiers);
                            }
                            onPositionChanged: (mouse) => {
                                if (shelfModule.isMarqueeActive) {
                                    var pos = mapToItem(listContainer, mouse.x, mouse.y);
                                    shelfModule.updateMarquee(pos.x, pos.y);
                                }
                            }
                            onReleased: (mouse) => {
                                if (shelfModule.isMarqueeActive) {
                                    var dist = Math.hypot(shelfModule.marqueeCurrentX - shelfModule.marqueeStartX, shelfModule.marqueeCurrentY - shelfModule.marqueeStartY);
                                    shelfModule.finishMarquee();
                                    if (dist < 4) {
                                        shelfModule.toggleSelect(filePath, index);
                                    }
                                }
                            }
                        }
                    }

                    // Smart File Type Icon
                    Text {
                        text: shelfModule.getFileIcon(name, filePath)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: Theme.colors.accent ?? "#7aa2f7"
                    }

                    // File Information (Draggable Area)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            spacing: 1

                            Text {
                                text: name
                                color: delegateRoot.isSelected ? (Theme.colors.accent ?? "#ffffff") : (Theme.colors.text_primary ?? "#c0caf5")
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

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.OpenHandCursor
                            preventStealing: true

                            drag.target: dragProxy
                            drag.axis: Drag.XAndYAxis

                            onPressed: (mouse) => {
                                shelfModule.prepareDragFor(filePath, index, mouse.modifiers);
                            }

                            onClicked: (mouse) => {
                                shelfModule.handleItemClick(filePath, index, mouse.modifiers);
                            }
                        }
                    }

                    // Remove Button
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: removeMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 11
                            color: removeMouse.containsMouse ? "#f44336" : (Theme.colors.text_secondary ?? "#565f89")
                        }

                        MouseArea {
                            id: removeMouse
                            anchors.fill: parent
                            hoverEnabled: true
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
            }
        }

        // Marquee Selection Visual Box
        Rectangle {
            id: marqueeVisual
            visible: shelfModule.isMarqueeActive
            x: Math.min(shelfModule.marqueeStartX, shelfModule.marqueeCurrentX)
            y: Math.min(shelfModule.marqueeStartY, shelfModule.marqueeCurrentY)
            width: Math.abs(shelfModule.marqueeCurrentX - shelfModule.marqueeStartX)
            height: Math.abs(shelfModule.marqueeCurrentY - shelfModule.marqueeStartY)
            color: Qt.rgba(0.48, 0.64, 0.97, 0.18)
            border.color: Theme.colors.accent ?? "#7aa2f7"
            border.width: 1
            radius: 4
            z: 90
        }

        // Central Drag Proxy with floating visual badge
        Item {
            id: dragProxy
            width: dragBadge.width
            height: dragBadge.height
            visible: Drag.active
            z: 999

            Drag.active: false
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.mimeData: {
                "text/uri-list": shelfModule.dragUriList
            }

            Drag.onDragFinished: (dropAction) => {
                shelfModule.handleDragCompleted(dropAction);
            }

            Rectangle {
                id: dragBadge
                width: dragRow.implicitWidth + 24
                height: 32
                radius: 8
                color: Theme.colors.card_bg ?? "#1f2335"
                border.width: 1.5
                border.color: Theme.colors.accent ?? "#7aa2f7"

                Row {
                    id: dragRow
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "󰉍"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        color: Theme.colors.accent ?? "#7aa2f7"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: shelfModule.dragLabelText
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.colors.text_primary ?? "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    // Bottom Status / Drag Hint Bar
    RowLayout {
        Layout.fillWidth: true
        visible: shelfModel.count > 0
        spacing: 6

        Text {
            text: "󰅁"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.colors.accent ?? "#7aa2f7"
        }

        Text {
            text: shelfModule.selectedCount > 0 
                ? (shelfModule.selectedCount + " selected • Drag to folder/browser, or press Enter to copy")
                : "Touchpad: Swipe left edge to box-select, or drag any file to drop"
            font.pixelSize: 10
            color: Theme.colors.text_secondary ?? "#565f89"
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
}
