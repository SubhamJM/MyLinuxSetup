import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: themeSelector
    spacing: 6
    Layout.fillWidth: true
    Layout.fillHeight: true

    property alias searchInput: searchInput
    property alias carousel: carousel
    property var allThemes: []
    property var filteredThemes: []

    Component.onCompleted: {
        themeScanner.running = true;
    }

    Connections {
        target: Theme
        function onCurrentThemeNameChanged() {
            themeSelector.selectActiveTheme(false);
        }
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode === "theme") {
                themeSelector.resetSearch();
                Qt.callLater(() => {
                    themeSelector.selectActiveTheme(false);
                    searchInput.forceActiveFocus();
                });
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (allThemes.length === 0 && !themeScanner.running) {
                themeScanner.running = true;
            } else {
                filterThemes();
                selectActiveTheme(false);
            }
            searchInput.forceActiveFocus();
        }
    }

    function forceThemeFocus() {
        searchInput.forceActiveFocus();
    }

    function resetSearch() {
        if (searchInput.text !== "") {
            searchInput.text = "";
        }
        filterThemes();
        selectActiveTheme(false);
    }

    function filterThemes() {
        var q = searchInput.text.trim().toLowerCase();
        if (!q) {
            filteredThemes = allThemes.slice();
        } else {
            filteredThemes = allThemes.filter(function(t) {
                return (t.themeName && t.themeName.toLowerCase().indexOf(q) !== -1) ||
                       (t.rawName && t.rawName.toLowerCase().indexOf(q) !== -1);
            });
        }
    }

    function selectActiveTheme(animate) {
        var cur = (Theme.currentThemeName || "").toLowerCase().trim();
        var foundIdx = -1;
        for (var i = 0; i < filteredThemes.length; i++) {
            var item = filteredThemes[i];
            if ((item.rawName && item.rawName.toLowerCase().trim() === cur) ||
                (item.themeName && item.themeName.toLowerCase().trim() === cur)) {
                foundIdx = i;
                break;
            }
        }
        if (foundIdx >= 0) {
            if (!animate) carousel.highlightMoveDuration = 0;
            carousel.currentIndex = foundIdx;
            carousel.positionViewAtIndex(foundIdx, ListView.Center);
            if (!animate) Qt.callLater(() => carousel.highlightMoveDuration = 220);
        } else if (filteredThemes.length > 0) {
            carousel.currentIndex = 0;
            carousel.positionViewAtIndex(0, ListView.Center);
        }
    }

    function applyCurrentTheme() {
        if (carousel.currentIndex >= 0 && carousel.currentIndex < filteredThemes.length) {
            var t = filteredThemes[carousel.currentIndex];
            if (t && t.rawName) {
                if (themeRunner.running) themeRunner.running = false;
                themeRunner.command = ["sh", "-c", "~/.config/scripts/apply-theme.sh " + t.rawName];
                themeRunner.running = true;
                root.activeMode = "idle";
            }
        }
    }

    // Scans all themes in ~/.config/themes via python helper
    Process {
        id: themeScanner
        running: false
        command: ["python3", (Quickshell.shellDir || Quickshell.configDir) + "/scripts/theme_scanner.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    if (Array.isArray(data)) {
                        allThemes = data;
                        themeSelector.filterThemes();
                        Qt.callLater(() => themeSelector.selectActiveTheme(false));
                    }
                } catch(e) {
                    console.error("Theme JSON parse error:", e);
                }
            }
        }
    }

    Process {
        id: themeRunner
        running: false
        onExited: Theme.reload()
    }

    // ==========================================
    // TOP BAR: Search Field & Index Counter
    // ==========================================
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        // Back to Utility Button
        Rectangle {
            width: 24; height: 24; radius: 7
            color: themeBackMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
            border.width: 1
            border.color: Theme.colors.border ?? "#16161e"
            scale: themeBackMouse.pressed ? 0.90 : 1.0
            Behavior on scale { NumberAnimation { duration: 90 } }

            Text {
                anchors.centerIn: parent
                text: "󰁍"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.colors.text_primary ?? "#c0caf5"
            }

            MouseArea {
                id: themeBackMouse
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.switchMode("utility", true)
            }
        }

        // Search Icon
        Text {
            text: "⌕"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: searchInput.activeFocus ? (Theme.colors.accent ?? "#2dd4bf") : (Theme.colors.text_secondary ?? "#6c7086")
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Search TextField
        TextField {
            id: searchInput
            focus: true
            selectByMouse: true
            Layout.fillWidth: true
            color: Theme.colors.text_primary ?? "#ffffff"
            font.family: "Inter"
            font.pixelSize: 13
            placeholderText: "Search themes..."
            placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
            background: Item {}
            leftPadding: 0

            onTextChanged: {
                themeSelector.filterThemes();
                if (themeSelector.filteredThemes.length > 0) {
                    carousel.currentIndex = 0;
                    carousel.positionViewAtIndex(0, ListView.Center);
                }
            }

            Keys.onLeftPressed: (event) => {
                if (cursorPosition === 0 || text.length === 0) {
                    if (carousel.currentIndex > 0) carousel.currentIndex--;
                    event.accepted = true;
                }
            }
            Keys.onRightPressed: (event) => {
                if (cursorPosition === text.length || text.length === 0) {
                    if (carousel.currentIndex < themeSelector.filteredThemes.length - 1) carousel.currentIndex++;
                    event.accepted = true;
                }
            }
            Keys.onUpPressed: (event) => {
                if (carousel.currentIndex > 0) carousel.currentIndex--;
                event.accepted = true;
            }
            Keys.onDownPressed: (event) => {
                if (carousel.currentIndex < themeSelector.filteredThemes.length - 1) carousel.currentIndex++;
                event.accepted = true;
            }
            Keys.onTabPressed: (event) => {
                if (carousel.currentIndex < themeSelector.filteredThemes.length - 1) carousel.currentIndex++;
                else carousel.currentIndex = 0;
                event.accepted = true;
            }
            Keys.onBacktabPressed: (event) => {
                if (carousel.currentIndex > 0) carousel.currentIndex--;
                else carousel.currentIndex = themeSelector.filteredThemes.length - 1;
                event.accepted = true;
            }
            Keys.onReturnPressed: (event) => {
                themeSelector.applyCurrentTheme();
                event.accepted = true;
            }
            Keys.onEnterPressed: (event) => {
                themeSelector.applyCurrentTheme();
                event.accepted = true;
            }
            Keys.onEscapePressed: (event) => {
                root.activeMode = "idle";
                event.accepted = true;
            }
        }

        // Counter (e.g. 2/19)
        Text {
            text: themeSelector.filteredThemes.length > 0 
                ? (carousel.currentIndex + 1) + "/" + themeSelector.filteredThemes.length 
                : "0/0"
            font.family: "Inter"
            font.pixelSize: 12
            color: Theme.colors.text_secondary ?? "#6c7086"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // ==========================================
    // CENTER: Horizontal Snapping Carousel
    // ==========================================
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 110

        Text {
            anchors.centerIn: parent
            visible: themeSelector.filteredThemes.length === 0 && !themeScanner.running
            text: "No matching themes found"
            font.family: "Inter"
            font.pixelSize: 13
            color: Theme.colors.text_secondary ?? "#6c7086"
        }

        ListView {
            id: carousel
            anchors.fill: parent
            orientation: ListView.Horizontal
            spacing: 14
            clip: true
            model: themeSelector.filteredThemes

            snapMode: ListView.SnapToItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: centerOffset
            preferredHighlightEnd: centerOffset
            highlightMoveDuration: 220

            readonly property real centerOffset: Math.max(0, Math.round((width - 176) / 2))

            header: Item { 
                width: carousel.centerOffset
                height: carousel.height 
            }
            footer: Item { 
                width: carousel.centerOffset
                height: carousel.height 
            }

            onWidthChanged: {
                if (count > 0 && currentIndex >= 0) {
                    positionViewAtIndex(currentIndex, ListView.Center);
                }
            }

            // Mouse wheel support for horizontal scrolling
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.PointingHandCursor
                onWheel: (wheel) => {
                    wheel.accepted = true;
                    if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0) {
                        if (carousel.currentIndex < themeSelector.filteredThemes.length - 1) carousel.currentIndex++;
                    } else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0) {
                        if (carousel.currentIndex > 0) carousel.currentIndex--;
                    }
                }
            }

            delegate: Item {
                id: cardItem
                width: 176
                height: 104
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                readonly property bool isCurrent: ListView.isCurrentItem
                readonly property bool isCurrentActive: {
                    var cur = (Theme.currentThemeName || "").toLowerCase().trim();
                    return ((modelData.rawName || "").toLowerCase().trim() === cur) ||
                           ((modelData.themeName || "").toLowerCase().trim() === cur);
                }

                scale: isCurrent ? 1.0 : 0.94
                opacity: isCurrent ? 1.0 : 0.65
                transformOrigin: Item.Center

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                Rectangle {
                    id: cardRect
                    anchors.fill: parent
                    radius: 16
                    color: modelData.cardBg || "#181825"

                    border.width: cardItem.isCurrent ? 2 : 1
                    border.color: cardItem.isCurrent 
                        ? (Theme.colors.accent ?? "#2dd4bf") 
                        : (cardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05))

                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on border.width { NumberAnimation { duration: 120 } }

                    // Active desktop theme indicator dot (top-right corner)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 10
                        anchors.rightMargin: 10
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.colors.accent ?? "#2dd4bf"
                        visible: cardItem.isCurrentActive
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        // 6 Palette Color Dots (ANSI colors 1-6)
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 7

                            Repeater {
                                model: (modelData.palette && modelData.palette.length >= 6) 
                                    ? modelData.palette.slice(0, 6) 
                                    : ["#ef4444", "#10b981", "#f59e0b", "#3b82f6", "#8b5cf6", "#06b6d4"]

                                Rectangle {
                                    width: 13
                                    height: 13
                                    radius: 6.5
                                    color: modelData
                                }
                            }
                        }

                        // Theme Name Label
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.themeName || ""
                            font.family: "Inter"
                            font.pixelSize: 12
                            font.weight: cardItem.isCurrent ? Font.DemiBold : Font.Normal
                            color: cardItem.isCurrent ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#9399b2")
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (carousel.currentIndex === index) {
                                themeSelector.applyCurrentTheme();
                            } else {
                                carousel.currentIndex = index;
                            }
                            themeSelector.forceThemeFocus();
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // FOOTER: "Enter to apply"
    // ==========================================
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 18
        Layout.rightMargin: 12
        Layout.leftMargin: 12

        Item { Layout.fillWidth: true }

        Text {
            text: "Enter to apply"
            font.family: "Inter"
            font.pixelSize: 11
            color: Theme.colors.text_secondary ?? "#6c7086"
            opacity: footerMouse.containsMouse ? 1.0 : 0.8
            Behavior on opacity { NumberAnimation { duration: 120 } }

            MouseArea {
                id: footerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: themeSelector.applyCurrentTheme()
            }
        }
    }
}
