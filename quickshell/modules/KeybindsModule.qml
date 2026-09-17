import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: cheatsheetRoot
    Layout.fillWidth: true
    Layout.fillHeight: true

    property string currentCategory: "All"
    property string searchQuery: ""
    property var allBinds: []
    property bool justCopied: false
    property string copiedItemKey: ""

    property var filteredBinds: []

    // Add Keybind Drawer State
    property bool isAddingMode: false
    property bool modSuper: true
    property bool modShift: false
    property bool modCtrl: false
    property bool modAlt: false
    property string newKeyText: ""
    property string newCmdText: ""
    property string newDescText: ""
    property string newCatText: "Launchers"
    property string formError: ""

    // Toast feedback state
    property string toastMessage: ""
    property bool toastIsError: false

    readonly property color accentColor: Theme.colors.accent ?? "#7aa2f7"
    readonly property color cardColor: Theme.colors.card_bg ?? "#1f2335"
    readonly property color hoverColor: Theme.colors.hover_bg ?? "#24283b"
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    readonly property string fullKeyCombo: {
        var parts = [];
        if (modSuper) parts.push("SUPER");
        if (modCtrl) parts.push("CONTROL");
        if (modAlt) parts.push("ALT");
        if (modShift) parts.push("SHIFT");
        var k = newKeyText.trim();
        if (k !== "") parts.push(k);
        return parts.join(" + ");
    }

    function forceSearchFocus() {
        if (isAddingMode) {
            keyField.forceActiveFocus();
        } else {
            searchField.forceActiveFocus();
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (allBinds.length === 0) {
                parserProcess.running = true;
            } else {
                cheatsheetRoot.applyFilter();
            }
            Qt.callLater(forceSearchFocus);
        } else {
            isAddingMode = false;
            toastMessage = "";
        }
    }

    Component.onCompleted: {
        parserProcess.running = true;
    }

    function showToast(msg, isErr) {
        toastMessage = msg;
        toastIsError = isErr;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 2600
        repeat: false
        onTriggered: cheatsheetRoot.toastMessage = ""
    }

    // Parser process to fetch keybinds
    Process {
        id: parserProcess
        running: false
        command: ["python3", (Quickshell.shellDir || Quickshell.configDir) + "/scripts/keybinds_parser.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    cheatsheetRoot.allBinds = JSON.parse(this.text);
                    cheatsheetRoot.applyFilter();
                } catch (e) {
                    console.log("Error parsing keybinds JSON:", e);
                }
            }
        }
    }

    // Add keybind process
    Process {
        id: addProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var res = JSON.parse(this.text.trim());
                    if (res.status === "ok") {
                        cheatsheetRoot.showToast("✓ " + res.message, false);
                        cheatsheetRoot.isAddingMode = false;
                        cheatsheetRoot.clearAddForm();
                        parserProcess.running = true;
                    } else {
                        cheatsheetRoot.formError = res.message || "Failed to add keybinding";
                    }
                } catch (e) {
                    console.error("Add bind JSON parse error:", e);
                    parserProcess.running = true;
                }
            }
        }
    }

    // Remove keybind process
    Process {
        id: removeProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var res = JSON.parse(this.text.trim());
                    if (res.status === "ok") {
                        cheatsheetRoot.showToast("✓ " + res.message, false);
                        parserProcess.running = true;
                    } else {
                        cheatsheetRoot.showToast("✕ " + res.message, true);
                    }
                } catch (e) {
                    console.error("Remove bind JSON parse error:", e);
                    parserProcess.running = true;
                }
            }
        }
    }

    function clearAddForm() {
        modSuper = true;
        modShift = false;
        modCtrl = false;
        modAlt = false;
        newKeyText = "";
        newCmdText = "";
        newDescText = "";
        newCatText = "Launchers";
        formError = "";
    }

    function submitNewKeybind() {
        formError = "";
        var k = fullKeyCombo.trim();
        var c = newCmdText.trim();
        var d = newDescText.trim();
        var cat = newCatText.trim() || "Custom";

        if (newKeyText.trim() === "") {
            formError = "Please enter a key (e.g. K, Return, F12, d)";
            keyField.forceActiveFocus();
            return;
        }

        if (c === "") {
            formError = "Please enter a command to execute";
            cmdField.forceActiveFocus();
            return;
        }

        if (addProcess.running) addProcess.running = false;
        addProcess.command = [
            "python3",
            (Quickshell.shellDir || Quickshell.configDir) + "/scripts/keybinds_parser.py",
            "add",
            "--key", k,
            "--cmd", c,
            "--desc", d,
            "--cat", cat
        ];
        addProcess.running = true;
    }

    function removeKeybind(item) {
        if (!item) return;
        if (removeProcess.running) removeProcess.running = false;
        var args = [
            "python3",
            (Quickshell.shellDir || Quickshell.configDir) + "/scripts/keybinds_parser.py",
            "remove"
        ];
        if (item.lineNum && item.lineNum > 0) {
            args.push("--line", String(item.lineNum));
        }
        if (item.key) {
            args.push("--key", item.key);
        }
        if (item.rawLine) {
            args.push("--raw", item.rawLine);
        }
        removeProcess.command = args;
        removeProcess.running = true;
    }

    function applyFilter() {
        var list = [];
        var q = cheatsheetRoot.searchQuery.toLowerCase().trim();
        var cat = cheatsheetRoot.currentCategory;

        for (var i = 0; i < allBinds.length; i++) {
            var item = allBinds[i];
            var matchesCat = (cat === "All" || item.cat === cat);
            var matchesQuery = (q === "" || 
                                item.key.toLowerCase().includes(q) || 
                                item.desc.toLowerCase().includes(q) || 
                                (item.cmd && item.cmd.toLowerCase().includes(q)));
            if (matchesCat && matchesQuery) {
                list.push(item);
            }
        }
        cheatsheetRoot.filteredBinds = list;
    }

    function copyBind(keyText) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(keyText) + " | wl-copy"]);
        cheatsheetRoot.copiedItemKey = keyText;
        cheatsheetRoot.justCopied = true;
        copiedTimer.restart();
    }

    Timer {
        id: copiedTimer
        interval: 1400
        repeat: false
        onTriggered: {
            cheatsheetRoot.justCopied = false;
            cheatsheetRoot.copiedItemKey = "";
        }
    }

    function getCatColor(c) {
        switch (c) {
            case "Launchers":  return "#7aa2f7"; // Blue
            case "Window":     return "#7dcfff"; // Cyan
            case "Workspaces": return "#bb9af7"; // Purple
            case "Media":      return "#73daca"; // Mint/Green
            case "System":     return "#e0af68"; // Amber
            case "Custom":     return "#ff757f"; // Coral
            default:           return "#c0caf5";
        }
    }

    function getCatCount(c) {
        if (c === "All") return allBinds.length;
        var count = 0;
        for (var i = 0; i < allBinds.length; i++) {
            if (allBinds[i].cat === c) count++;
        }
        return count;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ================= HEADER & ACTIONS =================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Back Button
            Rectangle {
                width: 26; height: 26; radius: 13
                color: backMouse.containsMouse ? cheatsheetRoot.hoverColor : "transparent"
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

            // Title
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter
                Text {
                    text: "󰌌"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: cheatsheetRoot.accentColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Hyprland Keybindings"
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.colors.text_primary ?? "#c0caf5"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Search Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                Layout.preferredWidth: 260
                Layout.preferredHeight: 32
                radius: 16
                color: cheatsheetRoot.cardColor
                border.width: 1
                border.color: searchField.activeFocus ? cheatsheetRoot.accentColor : Qt.rgba(1, 1, 1, 0.08)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "⌕"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: searchField.activeFocus ? cheatsheetRoot.accentColor : (Theme.colors.text_secondary ?? "#565f89")
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 80
                        font.family: "Inter"
                        font.pixelSize: 12
                        color: Theme.colors.text_primary ?? "#c0caf5"
                        placeholderText: "Search binds (e.g. super + shift, screenshot, terminal)..."
                        placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                        background: Item {}

                        onTextChanged: {
                            cheatsheetRoot.searchQuery = text;
                            cheatsheetRoot.applyFilter();
                        }

                        Keys.onEscapePressed: root.collapseToIdle()
                    }

                    Rectangle {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        radius: 9
                        visible: searchField.text.length > 0
                        color: clearMouse.containsMouse ? cheatsheetRoot.hoverColor : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 10
                            color: Theme.colors.text_secondary ?? "#565f89"
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                searchField.text = "";
                                searchField.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // Bind count badge
            Rectangle {
                Layout.preferredHeight: 26
                Layout.preferredWidth: countText.implicitWidth + 14
                radius: 13
                color: Qt.rgba(cheatsheetRoot.accentColor.r, cheatsheetRoot.accentColor.g, cheatsheetRoot.accentColor.b, 0.14)

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: cheatsheetRoot.filteredBinds.length + " binds"
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: cheatsheetRoot.accentColor
                }
            }

            // "+ Add Bind" Button
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: addBtnRow.implicitWidth + 18
                radius: 14
                color: cheatsheetRoot.isAddingMode
                    ? cheatsheetRoot.accentColor 
                    : (addBtnMouse.containsMouse ? Qt.rgba(cheatsheetRoot.accentColor.r, cheatsheetRoot.accentColor.g, cheatsheetRoot.accentColor.b, 0.22) : Qt.rgba(cheatsheetRoot.accentColor.r, cheatsheetRoot.accentColor.g, cheatsheetRoot.accentColor.b, 0.12))
                border.width: 1
                border.color: cheatsheetRoot.accentColor
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: addBtnRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: cheatsheetRoot.isAddingMode ? "✕" : "󰐕"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: cheatsheetRoot.isAddingMode ? 11 : 13
                        font.weight: Font.Bold
                        color: cheatsheetRoot.isAddingMode ? "#12141c" : cheatsheetRoot.accentColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: cheatsheetRoot.isAddingMode ? "Close" : "Add Bind"
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: cheatsheetRoot.isAddingMode ? "#12141c" : cheatsheetRoot.accentColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: addBtnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        cheatsheetRoot.isAddingMode = !cheatsheetRoot.isAddingMode;
                        if (cheatsheetRoot.isAddingMode) {
                            cheatsheetRoot.formError = "";
                            Qt.callLater(() => keyField.forceActiveFocus());
                        } else {
                            Qt.callLater(() => searchField.forceActiveFocus());
                        }
                    }
                }
            }
        }

        // Toast Feedback Notification Banner
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: cheatsheetRoot.toastMessage !== "" ? 26 : 0
            visible: Layout.preferredHeight > 0
            radius: 8
            color: cheatsheetRoot.toastIsError ? Qt.rgba(0.97, 0.46, 0.56, 0.2) : Qt.rgba(0.18, 0.83, 0.5, 0.2)
            border.width: 1
            border.color: cheatsheetRoot.toastIsError ? "#f7768e" : "#73daca"
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 160 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Text {
                    text: cheatsheetRoot.toastMessage
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: cheatsheetRoot.toastIsError ? "#f7768e" : "#73daca"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "✕"
                    font.pixelSize: 10
                    color: cheatsheetRoot.toastIsError ? "#f7768e" : "#73daca"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cheatsheetRoot.toastMessage = ""
                    }
                }
            }
        }

        // ================= ADD KEYBIND DRAWER =================
        Rectangle {
            id: addDrawer
            Layout.fillWidth: true
            Layout.preferredHeight: cheatsheetRoot.isAddingMode ? 190 : 0
            visible: Layout.preferredHeight > 0
            radius: 12
            color: cheatsheetRoot.cardColor
            border.width: 1
            border.color: Qt.rgba(cheatsheetRoot.accentColor.r, cheatsheetRoot.accentColor.g, cheatsheetRoot.accentColor.b, 0.35)
            clip: true

            Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Drawer Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰐕 Create New Hyprland Keybind"
                        font.family: "Inter"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: cheatsheetRoot.accentColor
                    }

                    // Live Badge Preview
                    Row {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: cheatsheetRoot.fullKeyCombo.split(" + ")
                            Rectangle {
                                height: 20
                                width: keyPrevText.implicitWidth + 10
                                radius: 5
                                color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1
                                border.color: cheatsheetRoot.accentColor

                                Text {
                                    id: keyPrevText
                                    anchors.centerIn: parent
                                    text: modelData.toUpperCase()
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: cheatsheetRoot.accentColor
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: cheatsheetRoot.formError !== ""
                        text: cheatsheetRoot.formError
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#f7768e"
                    }
                }

                // Row 1: Modifier toggles & Key field + Category selector
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Modifiers + Key
                    RowLayout {
                        spacing: 6

                        Text {
                            text: "Keys:"
                            font.family: "Inter"
                            font.pixelSize: 11
                            color: Theme.colors.text_secondary ?? "#565f89"
                        }

                        // Modifier chips
                        Repeater {
                            model: [
                                { name: "SUPER", prop: "modSuper" },
                                { name: "SHIFT", prop: "modShift" },
                                { name: "CTRL",  prop: "modCtrl" },
                                { name: "ALT",   prop: "modAlt" }
                            ]

                            Rectangle {
                                id: modChip
                                height: 24
                                width: modChipText.implicitWidth + 12
                                radius: 6
                                readonly property bool isActive: cheatsheetRoot[modelData.prop]
                                color: isActive ? Qt.rgba(cheatsheetRoot.accentColor.r, cheatsheetRoot.accentColor.g, cheatsheetRoot.accentColor.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1
                                border.color: isActive ? cheatsheetRoot.accentColor : Qt.rgba(1, 1, 1, 0.12)

                                Text {
                                    id: modChipText
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: modChip.isActive ? cheatsheetRoot.accentColor : (Theme.colors.text_secondary ?? "#565f89")
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: cheatsheetRoot[modelData.prop] = !cheatsheetRoot[modelData.prop]
                                }
                            }
                        }

                        Text {
                            text: "+"
                            font.pixelSize: 11
                            color: Theme.colors.text_secondary ?? "#565f89"
                        }

                        // Key Input Field
                        Rectangle {
                            width: 130
                            height: 26
                            radius: 6
                            color: Qt.rgba(0, 0, 0, 0.3)
                            border.width: 1
                            border.color: keyField.activeFocus ? cheatsheetRoot.accentColor : Qt.rgba(1, 1, 1, 0.15)

                            TextField {
                                id: keyField
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                font.family: "Inter"
                                font.pixelSize: 11
                                color: Theme.colors.text_primary ?? "#ffffff"
                                placeholderText: "Key (e.g. K, Return)"
                                placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                                background: Item {}
                                onTextChanged: cheatsheetRoot.newKeyText = text
                                Keys.onReturnPressed: cheatsheetRoot.submitNewKeybind()
                                Keys.onEscapePressed: cheatsheetRoot.isAddingMode = false
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Category Selector Pills
                    RowLayout {
                        spacing: 4

                        Text {
                            text: "Category:"
                            font.family: "Inter"
                            font.pixelSize: 11
                            color: Theme.colors.text_secondary ?? "#565f89"
                        }

                        Repeater {
                            model: ["Launchers", "Window", "Media", "System", "Custom"]

                            Rectangle {
                                id: catSelectChip
                                height: 24
                                width: catSelectText.implicitWidth + 12
                                radius: 12
                                readonly property bool isSelected: cheatsheetRoot.newCatText === modelData
                                color: isSelected 
                                    ? Qt.rgba(cheatsheetRoot.getCatColor(modelData).r, cheatsheetRoot.getCatColor(modelData).g, cheatsheetRoot.getCatColor(modelData).b, 0.25)
                                    : Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: isSelected ? cheatsheetRoot.getCatColor(modelData) : Qt.rgba(1, 1, 1, 0.1)

                                Text {
                                    id: catSelectText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: "Inter"
                                    font.pixelSize: 10
                                    font.weight: catSelectChip.isSelected ? Font.DemiBold : Font.Normal
                                    color: catSelectChip.isSelected ? cheatsheetRoot.getCatColor(modelData) : (Theme.colors.text_secondary ?? "#565f89")
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: cheatsheetRoot.newCatText = modelData
                                }
                            }
                        }
                    }
                }

                // Row 2: Command & Description fields
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Command Field
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.width: 1
                        border.color: cmdField.activeFocus ? cheatsheetRoot.accentColor : Qt.rgba(1, 1, 1, 0.15)

                        TextField {
                            id: cmdField
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: Theme.colors.text_primary ?? "#ffffff"
                            placeholderText: "Command (e.g. pavucontrol, firefox, hyprshot -m window)..."
                            placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                            background: Item {}
                            onTextChanged: cheatsheetRoot.newCmdText = text
                            Keys.onReturnPressed: cheatsheetRoot.submitNewKeybind()
                            Keys.onEscapePressed: cheatsheetRoot.isAddingMode = false
                        }
                    }

                    // Description Field
                    Rectangle {
                        Layout.preferredWidth: 260
                        height: 28
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.width: 1
                        border.color: descField.activeFocus ? cheatsheetRoot.accentColor : Qt.rgba(1, 1, 1, 0.15)

                        TextField {
                            id: descField
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            font.family: "Inter"
                            font.pixelSize: 11
                            color: Theme.colors.text_primary ?? "#ffffff"
                            placeholderText: "Description (e.g. Open Audio Mixer)..."
                            placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
                            background: Item {}
                            onTextChanged: cheatsheetRoot.newDescText = text
                            Keys.onReturnPressed: cheatsheetRoot.submitNewKeybind()
                            Keys.onEscapePressed: cheatsheetRoot.isAddingMode = false
                        }
                    }
                }

                // Row 3: Presets & Action Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Presets:"
                        font.family: "Inter"
                        font.pixelSize: 10
                        color: Theme.colors.text_secondary ?? "#565f89"
                    }

                    // Quick presets
                    Repeater {
                        model: [
                            { label: "󰆍 Kitty", cmd: "kitty", desc: "Launch Kitty Terminal", cat: "Launchers" },
                            { label: "󰈹 Zen", cmd: "zen-browser", desc: "Launch Web Browser", cat: "Launchers" },
                            { label: "󰕾 Audio", cmd: "pavucontrol", desc: "Open Volume Mixer", cat: "Media" },
                            { label: "󰍹 Snip", cmd: "grimblast --notify copysave area", desc: "Snip Screenshot", cat: "Media" },
                            { label: "󰊠 Yazi", cmd: "kitty --class yazi -e yazi", desc: "Terminal File Manager", cat: "Launchers" }
                        ]

                        Rectangle {
                            height: 20
                            width: presetText.implicitWidth + 10
                            radius: 10
                            color: presetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)

                            Text {
                                id: presetText
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                color: Theme.colors.text_secondary ?? "#a9b1d6"
                            }

                            MouseArea {
                                id: presetMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    cmdField.text = modelData.cmd;
                                    descField.text = modelData.desc;
                                    cheatsheetRoot.newCatText = modelData.cat;
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Cancel
                    Rectangle {
                        height: 26
                        width: 65
                        radius: 13
                        color: cancelBtnMouse.containsMouse ? cheatsheetRoot.hoverColor : "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.family: "Inter"
                            font.pixelSize: 11
                            color: Theme.colors.text_secondary ?? "#565f89"
                        }

                        MouseArea {
                            id: cancelBtnMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                cheatsheetRoot.isAddingMode = false;
                                searchField.forceActiveFocus();
                            }
                        }
                    }

                    // Submit Add Button
                    Rectangle {
                        height: 26
                        width: saveBtnText.implicitWidth + 20
                        radius: 13
                        color: (cheatsheetRoot.newKeyText.trim() === "" || cheatsheetRoot.newCmdText.trim() === "")
                            ? Qt.rgba(cheatsheetRoot.accentColor.r, cheatsheetRoot.accentColor.g, cheatsheetRoot.accentColor.b, 0.3)
                            : (saveBtnMouse.containsMouse ? Qt.lighter(cheatsheetRoot.accentColor, 1.1) : cheatsheetRoot.accentColor)

                        Text {
                            id: saveBtnText
                            anchors.centerIn: parent
                            text: "󰐕 Save Keybind"
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: "#12141c"
                        }

                        MouseArea {
                            id: saveBtnMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: cheatsheetRoot.submitNewKeybind()
                        }
                    }
                }
            }
        }

        // ================= CATEGORY FILTER PILLS =================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            spacing: 4

            Repeater {
                model: ["All", "Launchers", "Window", "Workspaces", "Media", "System", "Custom"]

                Rectangle {
                    id: catPill
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: catRow.implicitWidth + 12
                    radius: 12
                    property bool isCurrent: cheatsheetRoot.currentCategory === modelData
                    color: isCurrent 
                        ? Qt.rgba(cheatsheetRoot.accentColor.r, cheatsheetRoot.accentColor.g, cheatsheetRoot.accentColor.b, 0.22)
                        : (catMouse.containsMouse ? cheatsheetRoot.hoverColor : cheatsheetRoot.cardColor)
                    border.width: 1
                    border.color: isCurrent ? cheatsheetRoot.accentColor : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: catRow
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            width: 5; height: 5; radius: 2.5
                            color: cheatsheetRoot.getCatColor(modelData)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData !== "All"
                        }

                        Text {
                            text: modelData
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.weight: catPill.isCurrent ? Font.DemiBold : Font.Normal
                            color: catPill.isCurrent ? "white" : (Theme.colors.text_secondary ?? "#565f89")
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "(" + cheatsheetRoot.getCatCount(modelData) + ")"
                            font.family: "Inter"
                            font.pixelSize: 9
                            color: catPill.isCurrent ? cheatsheetRoot.accentColor : (Theme.colors.text_secondary ?? "#565f89")
                            opacity: 0.8
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: catMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            cheatsheetRoot.currentCategory = modelData;
                            cheatsheetRoot.applyFilter();
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "💡 Click to copy • 󰆴 to delete"
                font.family: "Inter"
                font.pixelSize: 10
                color: Theme.colors.text_secondary ?? "#565f89"
            }
        }

        // ================= KEYBIND CARDS LIST =================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: bindsView
                anchors.fill: parent
                clip: true
                spacing: 6
                model: cheatsheetRoot.filteredBinds

                boundsBehavior: Flickable.DragAndOvershootBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                    contentItem: Rectangle {
                        radius: 2
                        color: Theme.colors.text_secondary ?? "#565f89"
                        opacity: 0.4
                    }
                }

                delegate: Rectangle {
                    id: bindCard
                    width: ListView.view.width
                    height: 48
                    radius: 10
                    readonly property var bindItem: modelData
                    property bool isThisCopied: cheatsheetRoot.justCopied && (cheatsheetRoot.copiedItemKey === bindItem.key)
                    property bool isConfirmingDelete: false

                    color: isThisCopied
                        ? Qt.rgba(0.18, 0.83, 0.5, 0.2)
                        : (cardMouse.containsMouse ? cheatsheetRoot.hoverColor : cheatsheetRoot.cardColor)
                    border.width: 1
                    border.color: isThisCopied 
                        ? "#73daca" 
                        : (bindCard.isConfirmingDelete 
                            ? "#f7768e" 
                            : (cardMouse.containsMouse ? Qt.rgba(cheatsheetRoot.accentColor.r, cheatsheetRoot.accentColor.g, cheatsheetRoot.accentColor.b, 0.3) : Qt.rgba(1, 1, 1, 0.05)))
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Keyboard Keys Group
                        Row {
                            Layout.preferredWidth: 260
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter

                            Repeater {
                                model: (bindCard.bindItem && bindCard.bindItem.keys) ? bindCard.bindItem.keys : []

                                Rectangle {
                                    height: 24
                                    width: keyCapText.implicitWidth + 12
                                    radius: 6
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.18)

                                    // 3D keycap effect
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 2
                                        radius: 2
                                        color: Qt.rgba(0, 0, 0, 0.4)
                                    }

                                    Text {
                                        id: keyCapText
                                        anchors.centerIn: parent
                                        text: modelData.toLowerCase() === "slash" ? "/" : modelData.toUpperCase()
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Theme.colors.text_primary ?? "white"
                                    }
                                }
                            }
                        }

                        // Category Pill Tag
                        Rectangle {
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: catTagText.implicitWidth + 10
                            radius: 9
                            color: Qt.rgba(cheatsheetRoot.getCatColor(bindCard.bindItem.cat).r, cheatsheetRoot.getCatColor(bindCard.bindItem.cat).g, cheatsheetRoot.getCatColor(bindCard.bindItem.cat).b, 0.15)

                            Text {
                                id: catTagText
                                anchors.centerIn: parent
                                text: bindCard.bindItem.cat
                                font.family: "Inter"
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: cheatsheetRoot.getCatColor(bindCard.bindItem.cat)
                            }
                        }

                        // Action Description
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: bindCard.bindItem.desc
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.colors.text_primary ?? "#c0caf5"
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: bindCard.bindItem.cmd
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: Theme.colors.text_secondary ?? "#565f89"
                                elide: Text.ElideRight
                            }
                        }

                        // Action Buttons / Inline Delete Confirmation
                        Item {
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: actionRow.implicitWidth
                            Layout.alignment: Qt.AlignVCenter

                            // Standard Copy & Delete icons
                            Row {
                                id: actionRow
                                visible: !bindCard.isConfirmingDelete
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                // Copy button
                                Rectangle {
                                    width: 26; height: 26; radius: 6
                                    color: copyBtnMouse.containsMouse ? cheatsheetRoot.hoverColor : "transparent"
                                    border.width: 1
                                    border.color: copyBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: bindCard.isThisCopied ? "✓" : "󰆏"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        color: bindCard.isThisCopied ? "#73daca" : (copyBtnMouse.containsMouse ? cheatsheetRoot.accentColor : (Theme.colors.text_secondary ?? "#565f89"))
                                    }

                                    MouseArea {
                                        id: copyBtnMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: cheatsheetRoot.copyBind(bindCard.bindItem.key)
                                    }
                                }

                                // Delete button
                                Rectangle {
                                    width: 26; height: 26; radius: 6
                                    visible: bindCard.bindItem.canDelete !== false
                                    color: delBtnMouse.containsMouse ? Qt.rgba(0.97, 0.46, 0.56, 0.22) : "transparent"
                                    border.width: 1
                                    border.color: delBtnMouse.containsMouse ? "#f7768e" : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰆴"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        color: delBtnMouse.containsMouse ? "#f7768e" : (Theme.colors.text_secondary ?? "#565f89")
                                    }

                                    MouseArea {
                                        id: delBtnMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: bindCard.isConfirmingDelete = true
                                    }
                                }
                            }

                            // Inline Delete Confirmation Row
                            Row {
                                visible: bindCard.isConfirmingDelete
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "Delete?"
                                    font.family: "Inter"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: "#f7768e"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Cancel button
                                Rectangle {
                                    width: 20; height: 20; radius: 5
                                    color: cancelDelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.2)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        font.pixelSize: 9
                                        color: Theme.colors.text_secondary ?? "#565f89"
                                    }

                                    MouseArea {
                                        id: cancelDelMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: bindCard.isConfirmingDelete = false
                                    }
                                }

                                // Confirm Delete button
                                Rectangle {
                                    width: 20; height: 20; radius: 5
                                    color: confirmDelMouse.containsMouse ? "#f7768e" : Qt.rgba(0.97, 0.46, 0.56, 0.25)
                                    border.width: 1
                                    border.color: "#f7768e"
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: confirmDelMouse.containsMouse ? "#12141c" : "#f7768e"
                                    }

                                    MouseArea {
                                        id: confirmDelMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            bindCard.isConfirmingDelete = false;
                                            cheatsheetRoot.removeKeybind(bindCard.bindItem);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        // Pass click to copy bind if not clicking child buttons
                        onClicked: {
                            if (!bindCard.isConfirmingDelete) {
                                cheatsheetRoot.copyBind(bindCard.bindItem.key);
                            }
                        }
                    }
                }
            }

            // Empty Search State
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: cheatsheetRoot.filteredBinds.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰍉"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 26
                    color: Theme.colors.text_secondary ?? "#565f89"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No keybindings found matching \"" + cheatsheetRoot.searchQuery + "\""
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.colors.text_primary ?? "#c0caf5"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Try searching with different keywords like 'super', 'shift', 'window', or click '+ Add Bind' to create one."
                    font.family: "Inter"
                    font.pixelSize: 11
                    color: Theme.colors.text_secondary ?? "#565f89"
                }
            }
        }
    }
}
