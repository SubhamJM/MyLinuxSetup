import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: notesRoot
    Layout.fillWidth: true
    Layout.fillHeight: true

    property int activeTab: 0 // 0: Scratchpad, 1: Todos
    property string scratchpadText: ""
    property bool isSaving: false
    property bool justSaved: false
    property bool justCopied: false
    property bool justExported: false

    // Wide mode toggle (680px vs 820px)
    property bool isWideMode: false

    // File export state
    property bool isSaveDrawerOpen: false
    property string exportPath: "~/Documents/scratchpad.txt"
    readonly property string expandedExportPath: {
        if (exportPath.startsWith("~/")) {
            return Quickshell.env("HOME") + exportPath.substring(1);
        }
        return exportPath;
    }

    ListModel { id: todoModel }

    readonly property color accentColor: Theme.colors.accent ?? "#7aa2f7"
    readonly property color cardColor: Theme.colors.card_bg ?? "#1f2335"
    readonly property color hoverColor: Theme.colors.hover_bg ?? "#24283b"
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    readonly property int completedTodoCount: {
        var c = 0;
        for (var i = 0; i < todoModel.count; i++) {
            if (todoModel.get(i).done) c++;
        }
        return c;
    }

    function forceNotesFocus() {
        if (activeTab === 0) {
            scratchArea.forceActiveFocus();
        } else {
            newTodoInput.forceActiveFocus();
        }
    }

    onVisibleChanged: {
        if (visible) {
            loadProcess.running = true;
            Qt.callLater(forceNotesFocus);
        } else {
            notesRoot.isSaveDrawerOpen = false;
            notesRoot.justExported = false;
        }
    }

    Component.onCompleted: {
        loadProcess.running = true;
    }

    // ========================================================
    // PROCESSES: LOAD, SAVE & EXPORT
    // ========================================================
    // 1. Load from disk
    Process {
        id: loadProcess
        running: false
        command: [(Quickshell.shellDir || Quickshell.configDir) + "/scripts/notes_store.py", "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var data = JSON.parse(this.text);
                    if (data.scratchpad !== undefined && !scratchArea.activeFocus) {
                        notesRoot.scratchpadText = data.scratchpad;
                        scratchArea.text = data.scratchpad;
                    }
                    if (Array.isArray(data.todos)) {
                        todoModel.clear();
                        for (var i = 0; i < data.todos.length; i++) {
                            todoModel.append(data.todos[i]);
                        }
                    }
                } catch (e) {
                    console.log("Error loading notes JSON:", e);
                }
            }
        }
    }

    // 2. Auto-save Scratchpad
    Timer {
        id: autoSaveDebounce
        interval: 350
        repeat: false
        onTriggered: {
            notesRoot.isSaving = true;
            var enc = encodeURIComponent(scratchArea.text);
            saveScratchProcess.command = [(Quickshell.shellDir || Quickshell.configDir) + "/scripts/notes_store.py", "save_scratchpad_enc", enc];
            saveScratchProcess.running = true;
        }
    }

    Process {
        id: saveScratchProcess
        running: false
        onRunningChanged: {
            if (!running) {
                notesRoot.isSaving = false;
                notesRoot.justSaved = true;
                savedBadgeTimer.restart();
            }
        }
    }

    // 3. Save Todos
    function saveTodosToDisk() {
        var list = [];
        for (var i = 0; i < todoModel.count; i++) {
            var item = todoModel.get(i);
            list.push({
                "id": item.id,
                "text": item.text,
                "done": item.done
            });
        }
        var jsonStr = JSON.stringify(list);
        var enc = encodeURIComponent(jsonStr);
        saveTodosProcess.command = [(Quickshell.shellDir || Quickshell.configDir) + "/scripts/notes_store.py", "save_todos_enc", enc];
        saveTodosProcess.running = true;
    }

    Process {
        id: saveTodosProcess
        running: false
        onRunningChanged: {
            if (!running) {
                notesRoot.justSaved = true;
                savedBadgeTimer.restart();
            }
        }
    }

    // 4. Export Scratchpad as .txt to custom path
    function exportScratchpadToDisk(targetPath) {
        var path = targetPath.trim();
        if (path === "") return;
        notesRoot.exportPath = path;
        var enc = encodeURIComponent(scratchArea.text);
        exportProcess.targetPath = path;
        exportProcess.command = [(Quickshell.shellDir || Quickshell.configDir) + "/scripts/notes_store.py", "export_txt", path, enc];
        exportProcess.running = true;
    }

    Process {
        id: exportProcess
        running: false
        property string targetPath: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim();
                if (out.startsWith("OK:")) {
                    notesRoot.justExported = true;
                    notesRoot.isSaveDrawerOpen = false;
                    savedBadgeTimer.restart();
                    Quickshell.execDetached(["notify-send", "-a", "Quickshell Notes", "Scratchpad Saved", "Successfully saved to " + exportProcess.targetPath]);
                }
            }
        }
    }

    // 5. System native file picker (kdialog)
    Process {
        id: fileDialogProcess
        running: false
        command: ["kdialog", "--getsavefilename", notesRoot.expandedExportPath, "Text files (*.txt);;All files (*)"]
        stdout: StdioCollector {
            onStreamFinished: {
                var chosen = this.text.trim();
                if (chosen !== "") {
                    exportPathField.text = chosen;
                    notesRoot.exportScratchpadToDisk(chosen);
                }
            }
        }
    }

    Timer {
        id: savedBadgeTimer
        interval: 2200
        repeat: false
        onTriggered: {
            notesRoot.justSaved = false;
            notesRoot.justCopied = false;
            notesRoot.justExported = false;
        }
    }

    function copyScratchpad() {
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(scratchArea.text) + " | wl-copy"]);
        notesRoot.justCopied = true;
        savedBadgeTimer.restart();
    }

    function clearScratchpad() {
        scratchArea.text = "";
        notesRoot.scratchpadText = "";
        autoSaveDebounce.restart();
    }

    function addNewTodo(txt) {
        var clean = txt.trim();
        if (clean === "") return;
        todoModel.append({
            "id": Date.now(),
            "text": clean,
            "done": false
        });
        newTodoInput.text = "";
        saveTodosToDisk();
        todoListView.positionViewAtEnd();
    }

    function toggleTodoDone(idx) {
        if (idx >= 0 && idx < todoModel.count) {
            var item = todoModel.get(idx);
            item.done = !item.done;
            saveTodosToDisk();
        }
    }

    function removeTodo(idx) {
        if (idx >= 0 && idx < todoModel.count) {
            todoModel.remove(idx);
            saveTodosToDisk();
        }
    }

    function clearCompletedTodos() {
        for (var i = todoModel.count - 1; i >= 0; i--) {
            if (todoModel.get(i).done) {
                todoModel.remove(i);
            }
        }
        saveTodosToDisk();
    }

    // ========================================================
    // MAIN GEOMETRIC ROOT CONTAINER (Anchored to fill parent)
    // ========================================================
    Item {
        id: mainContainer
        anchors.fill: parent

        // ================= 1. HEADER BAR (Fixed to top) =================
        Item {
            id: headerBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 32

            RowLayout {
                anchors.fill: parent
                spacing: 8

                // Back button
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: backMouse.containsMouse ? notesRoot.hoverColor : "transparent"
                    border.width: 1
                    border.color: Theme.colors.border ?? "#16161e"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.colors.text_primary ?? "#c0caf5"
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (root.previousExpandedMode === "utility") {
                                root.switchMode("utility", true);
                            } else {
                                root.collapseToIdle();
                            }
                        }
                    }
                }

                // Title with Icon
                Row {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: "󰠮"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        color: notesRoot.accentColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Notes & Tasks"
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.colors.text_primary ?? "#c0caf5"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Segmented Tab Selector
                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 210
                    radius: 14
                    color: notesRoot.cardColor
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    // Sliding indicator
                    Rectangle {
                        x: notesRoot.activeTab === 0 ? 2 : parent.width / 2
                        y: 2
                        width: parent.width / 2 - 2
                        height: parent.height - 4
                        radius: 12
                        color: notesRoot.accentColor
                        opacity: 0.22

                        Behavior on x {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: notesRoot.motionCurve
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        Item {
                            width: parent.width / 2
                            height: parent.height
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "󰠮"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: notesRoot.activeTab === 0 ? notesRoot.accentColor : (Theme.colors.text_secondary ?? "#565f89")
                                }
                                Text {
                                    text: "Scratchpad"
                                    font.family: "Inter"
                                    font.pixelSize: 11
                                    font.weight: notesRoot.activeTab === 0 ? Font.DemiBold : Font.Normal
                                    color: notesRoot.activeTab === 0 ? (Theme.colors.text_primary ?? "white") : (Theme.colors.text_secondary ?? "#565f89")
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    notesRoot.activeTab = 0;
                                    scratchArea.forceActiveFocus();
                                }
                            }
                        }

                        Item {
                            width: parent.width / 2
                            height: parent.height
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "󰄲"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: notesRoot.activeTab === 1 ? notesRoot.accentColor : (Theme.colors.text_secondary ?? "#565f89")
                                }
                                Text {
                                    text: "Todos (" + todoModel.count + ")"
                                    font.family: "Inter"
                                    font.pixelSize: 11
                                    font.weight: notesRoot.activeTab === 1 ? Font.DemiBold : Font.Normal
                                    color: notesRoot.activeTab === 1 ? (Theme.colors.text_primary ?? "white") : (Theme.colors.text_secondary ?? "#565f89")
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    notesRoot.activeTab = 1;
                                    newTodoInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // ================= ACTION BUTTONS =================
                // 1. Scratchpad: Save As .txt Button
                Rectangle {
                    visible: notesRoot.activeTab === 0
                    Layout.preferredHeight: 25
                    Layout.preferredWidth: notesRoot.justExported ? 82 : 78
                    radius: 7
                    color: notesRoot.justExported
                        ? Qt.rgba(0.18, 0.83, 0.5, 0.22)
                        : (notesRoot.isSaveDrawerOpen ? Qt.rgba(notesRoot.accentColor.r, notesRoot.accentColor.g, notesRoot.accentColor.b, 0.25) : (saveDrawerMouse.containsMouse ? notesRoot.hoverColor : notesRoot.cardColor))
                    border.width: 1
                    border.color: notesRoot.justExported ? "#73daca" : (notesRoot.isSaveDrawerOpen ? notesRoot.accentColor : (Theme.colors.border ?? "#16161e"))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: notesRoot.justExported ? "✓" : "󰈔"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: notesRoot.justExported ? "#73daca" : (Theme.colors.text_primary ?? "#c0caf5")
                        }
                        Text {
                            text: notesRoot.justExported ? "Saved" : "Save As"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: notesRoot.justExported ? "#73daca" : (Theme.colors.text_primary ?? "#c0caf5")
                        }
                    }

                    MouseArea {
                        id: saveDrawerMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            notesRoot.isSaveDrawerOpen = !notesRoot.isSaveDrawerOpen;
                            if (notesRoot.isSaveDrawerOpen) exportPathField.forceActiveFocus();
                        }
                    }
                }

                // 2. Scratchpad: Copy Button
                Rectangle {
                    visible: notesRoot.activeTab === 0
                    Layout.preferredHeight: 25
                    Layout.preferredWidth: notesRoot.justCopied ? 68 : 62
                    radius: 7
                    color: notesRoot.justCopied 
                        ? Qt.rgba(0.18, 0.83, 0.5, 0.22) 
                        : (copyMouse.containsMouse ? notesRoot.hoverColor : notesRoot.cardColor)
                    border.width: 1
                    border.color: notesRoot.justCopied ? "#73daca" : (Theme.colors.border ?? "#16161e")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: notesRoot.justCopied ? "✓" : "󰆏"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: notesRoot.justCopied ? "#73daca" : (Theme.colors.text_primary ?? "#c0caf5")
                        }
                        Text {
                            text: notesRoot.justCopied ? "Copied" : "Copy"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: notesRoot.justCopied ? "#73daca" : (Theme.colors.text_primary ?? "#c0caf5")
                        }
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: notesRoot.copyScratchpad()
                    }
                }

                // 3. Scratchpad: Clear Button
                Rectangle {
                    visible: notesRoot.activeTab === 0 && scratchArea.text.trim() !== ""
                    Layout.preferredHeight: 25
                    Layout.preferredWidth: 54
                    radius: 7
                    color: clearMouse.containsMouse ? Qt.rgba(0.97, 0.46, 0.56, 0.2) : notesRoot.cardColor
                    border.width: 1
                    border.color: clearMouse.containsMouse ? "#f7768e" : (Theme.colors.border ?? "#16161e")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "󰅖"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: clearMouse.containsMouse ? "#f7768e" : (Theme.colors.text_secondary ?? "#565f89")
                        }
                        Text {
                            text: "Clear"
                            font.family: "Inter"
                            font.pixelSize: 10
                            color: clearMouse.containsMouse ? "#f7768e" : (Theme.colors.text_secondary ?? "#565f89")
                        }
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: notesRoot.clearScratchpad()
                    }
                }

                // 4. Todo: Clear Completed Button
                Rectangle {
                    visible: notesRoot.activeTab === 1 && notesRoot.completedTodoCount > 0
                    Layout.preferredHeight: 25
                    Layout.preferredWidth: 86
                    radius: 7
                    color: clearDoneMouse.containsMouse ? Qt.rgba(0.97, 0.46, 0.56, 0.2) : notesRoot.cardColor
                    border.width: 1
                    border.color: clearDoneMouse.containsMouse ? "#f7768e" : (Theme.colors.border ?? "#16161e")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰃢"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: clearDoneMouse.containsMouse ? "#f7768e" : (Theme.colors.text_secondary ?? "#565f89")
                        }
                        Text {
                            text: "Clear Done"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: clearDoneMouse.containsMouse ? "#f7768e" : (Theme.colors.text_secondary ?? "#565f89")
                        }
                    }

                    MouseArea {
                        id: clearDoneMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: notesRoot.clearCompletedTodos()
                    }
                }

                // 5. Dynamic Wide Mode Toggle Button
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 25
                    radius: 7
                    color: notesRoot.isWideMode ? Qt.rgba(notesRoot.accentColor.r, notesRoot.accentColor.g, notesRoot.accentColor.b, 0.25) : (wideMouse.containsMouse ? notesRoot.hoverColor : notesRoot.cardColor)
                    border.width: 1
                    border.color: notesRoot.isWideMode ? notesRoot.accentColor : (Theme.colors.border ?? "#16161e")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: notesRoot.isWideMode ? "󰆦" : "󰆤"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: notesRoot.isWideMode ? notesRoot.accentColor : (Theme.colors.text_primary ?? "#c0caf5")
                    }

                    MouseArea {
                        id: wideMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: notesRoot.isWideMode = !notesRoot.isWideMode
                    }
                }
            }
        }

        // ================= 2. SAVE AS .TXT DRAWER (Expandable) =================
        Rectangle {
            id: saveDrawer
            anchors.top: headerBar.bottom
            anchors.topMargin: notesRoot.isSaveDrawerOpen ? 6 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            height: notesRoot.isSaveDrawerOpen ? 36 : 0
            visible: height > 0
            clip: true
            radius: 9
            color: notesRoot.cardColor
            border.width: 1
            border.color: Qt.rgba(notesRoot.accentColor.r, notesRoot.accentColor.g, notesRoot.accentColor.b, 0.35)
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: "󰈔"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: notesRoot.accentColor
                }

                TextField {
                    id: exportPathField
                    Layout.fillWidth: true
                    text: notesRoot.exportPath
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: Theme.colors.text_primary ?? "#c0caf5"
                    placeholderText: "Enter destination path e.g. ~/Documents/notes.txt..."
                    placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                    background: Item {}

                    onAccepted: notesRoot.exportScratchpadToDisk(text)
                }

                // Browse Button (kdialog)
                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 68
                    radius: 6
                    color: browseMouse.containsMouse ? notesRoot.hoverColor : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Theme.colors.border ?? "#16161e"

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "📁"
                            font.pixelSize: 10
                        }
                        Text {
                            text: "Browse"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Theme.colors.text_primary ?? "#c0caf5"
                        }
                    }

                    MouseArea {
                        id: browseMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (!fileDialogProcess.running) fileDialogProcess.running = true;
                        }
                    }
                }

                // Save Confirm Button
                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 54
                    radius: 6
                    color: saveConfirmMouse.containsMouse ? notesRoot.accentColor : Qt.rgba(notesRoot.accentColor.r, notesRoot.accentColor.g, notesRoot.accentColor.b, 0.2)
                    border.width: 1
                    border.color: notesRoot.accentColor

                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        font.family: "Inter"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: saveConfirmMouse.containsMouse ? "white" : notesRoot.accentColor
                    }

                    MouseArea {
                        id: saveConfirmMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: notesRoot.exportScratchpadToDisk(exportPathField.text)
                    }
                }

                // Close Drawer Button
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 10
                    color: closeDrawerMouse.containsMouse ? notesRoot.hoverColor : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 10
                        color: Theme.colors.text_secondary ?? "#565f89"
                    }

                    MouseArea {
                        id: closeDrawerMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: notesRoot.isSaveDrawerOpen = false
                    }
                }
            }
        }

        // ================= 3. FOOTER STATUS BAR (Fixed to bottom) =================
        Item {
            id: footerBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 20

            // Footer for Scratchpad (Tab 0)
            RowLayout {
                anchors.fill: parent
                visible: notesRoot.activeTab === 0
                spacing: 8

                Text {
                    text: {
                        var chars = scratchArea.text.length;
                        var lines = scratchArea.text === "" ? 0 : scratchArea.text.split("\n").length;
                        return chars + " characters · " + lines + " lines";
                    }
                    font.family: "Inter"
                    font.pixelSize: 10
                    color: Theme.colors.text_secondary ?? "#565f89"
                }

                Item { Layout.fillWidth: true }

                // Live status info
                Row {
                    spacing: 4
                    visible: notesRoot.justSaved || notesRoot.isSaving || notesRoot.justExported
                    Text {
                        text: notesRoot.justExported ? "✓" : (notesRoot.isSaving ? "󰔛" : "󰄬")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: notesRoot.isSaving ? notesRoot.accentColor : "#73daca"
                    }
                    Text {
                        text: {
                            if (notesRoot.justExported) return "Saved to " + notesRoot.exportPath;
                            if (notesRoot.isSaving) return "Saving...";
                            return "Saved to cache";
                        }
                        font.family: "Inter"
                        font.pixelSize: 10
                        color: notesRoot.isSaving ? notesRoot.accentColor : "#73daca"
                    }
                }
            }

            // Footer for Todo Tasks (Tab 1)
            RowLayout {
                anchors.fill: parent
                visible: notesRoot.activeTab === 1
                spacing: 8

                Text {
                    text: notesRoot.completedTodoCount + " of " + todoModel.count + " completed"
                    font.family: "Inter"
                    font.pixelSize: 10
                    color: Theme.colors.text_secondary ?? "#565f89"
                }

                Item { Layout.fillWidth: true }

                // Progress Bar
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 5
                    radius: 3
                    color: notesRoot.cardColor

                    Rectangle {
                        height: parent.height
                        radius: 3
                        width: parent.width * (todoModel.count > 0 ? (notesRoot.completedTodoCount / todoModel.count) : 0)
                        color: notesRoot.completedTodoCount === todoModel.count ? "#73daca" : notesRoot.accentColor
                        Behavior on width { NumberAnimation { duration: 180 } }
                    }
                }
            }
        }

        // ================= 4. BODY CONTENT (Strictly bounded between header & footer) =================
        StackLayout {
            id: contentStack
            anchors.top: notesRoot.isSaveDrawerOpen ? saveDrawer.bottom : headerBar.bottom
            anchors.topMargin: 8
            anchors.bottom: footerBar.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            currentIndex: notesRoot.activeTab

            // ---------------- TAB 0: SCRATCHPAD ----------------
            Item {
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: notesRoot.cardColor
                    border.width: 1
                    border.color: scratchArea.activeFocus ? notesRoot.accentColor : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 5
                            contentItem: Rectangle {
                                radius: 3
                                color: Theme.colors.text_secondary ?? "#565f89"
                                opacity: 0.4
                            }
                        }

                        TextArea {
                            id: scratchArea
                            wrapMode: TextEdit.Wrap
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: Theme.colors.text_primary ?? "#c0caf5"
                            placeholderText: "Jot temporary notes, terminal snippets, API keys, or thoughts here...\nAuto-saved automatically in real time.\nClick 'Save As' or press Ctrl+S to save as .txt."
                            placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                            selectByMouse: true
                            background: Item {}

                            onTextChanged: {
                                notesRoot.scratchpadText = text;
                                autoSaveDebounce.restart();
                            }

                            Keys.onEscapePressed: root.collapseToIdle()
                            
                            // Ctrl+S shortcut to open Save As / Export drawer
                            Keys.onPressed: (event) => {
                                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                                    notesRoot.isSaveDrawerOpen = true;
                                    exportPathField.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- TAB 1: TODOS ----------------
            Item {
                anchors.fill: parent

                // Top Add Task Bar
                Rectangle {
                    id: addTodoBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 38
                    radius: 19
                    color: notesRoot.cardColor
                    border.width: 1
                    border.color: newTodoInput.activeFocus ? notesRoot.accentColor : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: "󰄱"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: notesRoot.accentColor
                        }

                        TextField {
                            id: newTodoInput
                            Layout.fillWidth: true
                            font.family: "Inter"
                            font.pixelSize: 12
                            color: Theme.colors.text_primary ?? "#c0caf5"
                            placeholderText: "Add a new task (Press Enter to add)..."
                            placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                            background: Item {}

                            onAccepted: notesRoot.addNewTodo(text)
                            Keys.onEscapePressed: root.collapseToIdle()
                        }

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: addBtnMouse.containsMouse ? notesRoot.accentColor : Qt.rgba(notesRoot.accentColor.r, notesRoot.accentColor.g, notesRoot.accentColor.b, 0.15)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 16
                                font.bold: true
                                color: addBtnMouse.containsMouse ? "white" : notesRoot.accentColor
                            }

                            MouseArea {
                                id: addBtnMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: notesRoot.addNewTodo(newTodoInput.text)
                            }
                        }
                    }
                }

                // Task List / Empty State container
                Item {
                    anchors.top: addTodoBar.bottom
                    anchors.topMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    ListView {
                        id: todoListView
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        model: todoModel

                        boundsBehavior: Flickable.DragAndOvershootBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 5
                            contentItem: Rectangle {
                                radius: 3
                                color: Theme.colors.text_secondary ?? "#565f89"
                                opacity: 0.4
                            }
                        }

                        add: Transition {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
                            NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 180; easing.type: Easing.OutBack }
                        }
                        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
                        displaced: Transition { NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic } }

                        delegate: Rectangle {
                            id: todoDelegate
                            width: ListView.view.width
                            height: 38
                            radius: 10
                            color: itemMouse.containsMouse ? notesRoot.hoverColor : notesRoot.cardColor
                            border.width: 1
                            border.color: done ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.08)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 10

                                // Checkbox Toggle
                                Rectangle {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    radius: 6
                                    color: done ? notesRoot.accentColor : "transparent"
                                    border.width: done ? 0 : 1.5
                                    border.color: done ? "transparent" : (Theme.colors.text_secondary ?? "#565f89")
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "white"
                                        visible: done
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notesRoot.toggleTodoDone(index)
                                    }
                                }

                                // Task Text
                                Text {
                                    Layout.fillWidth: true
                                    text: model.text
                                    font.family: "Inter"
                                    font.pixelSize: 12
                                    font.strikeout: done
                                    color: done 
                                        ? (Theme.colors.text_secondary ?? "#565f89") 
                                        : (Theme.colors.text_primary ?? "#c0caf5")
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                }

                                // Delete Button
                                Rectangle {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    radius: 11
                                    color: delMouse.containsMouse ? Qt.rgba(0.97, 0.46, 0.56, 0.2) : "transparent"
                                    opacity: itemMouse.containsMouse ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        font.pixelSize: 10
                                        color: delMouse.containsMouse ? "#f7768e" : (Theme.colors.text_secondary ?? "#565f89")
                                    }

                                    MouseArea {
                                        id: delMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notesRoot.removeTodo(index)
                                    }
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                z: -1
                                onClicked: notesRoot.toggleTodoDone(index)
                            }
                        }
                    }

                    // Empty State
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: todoModel.count === 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰄵"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 26
                            color: notesRoot.accentColor
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "All tasks completed!"
                            font.family: "Inter"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.colors.text_primary ?? "#c0caf5"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Type a task above and hit Enter to add."
                            font.family: "Inter"
                            font.pixelSize: 10
                            color: Theme.colors.text_secondary ?? "#565f89"
                        }
                    }
                }
            }
        }
    }
}
