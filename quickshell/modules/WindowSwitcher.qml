import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland // Required for ToplevelManager and ScreencopyView
import "../"

ColumnLayout {
    id: winSwitcher
    spacing: 10
    Layout.fillWidth: true
    Layout.fillHeight: true

    focus: true

    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
            winSwitcher.activateSelected();
            event.accepted = true;
        }
    }

    property alias windowGrid: windowCarousel
    property bool pendingActivation: false
    ListModel { id: clientsModel }

    readonly property int calculatedCount: clientsModel.count

    function refreshClients() {
        // Clear the model instantly to prevent flashing stale data from previous Alt+Tabs
        clientsModel.clear(); 
        pendingActivation = false;
        
        if (clientScanner.running) clientScanner.running = false;
        clientScanner.running = true;
    }

    function cycleNext() {
        if (clientsModel.count > 0) windowCarousel.incrementCurrentIndex();
    }

    function cyclePrev() {
        if (clientsModel.count > 0) windowCarousel.decrementCurrentIndex();
    }

    // Delay buffer to allow Wayland layer surface grab release prior to dispatch
    Timer {
        id: focusDelayTimer
        interval: 50
        repeat: false
        property string targetAddress: ""
        onTriggered: {
            if (typeof Hyprland !== "undefined") {
                if (Hyprland.usingLua) {
                    Hyprland.dispatch(`hl.dsp.focus({ window = 'address:${targetAddress}' })`);
                } else {
                    Hyprland.dispatch(`focuswindow address:${targetAddress}`);
                }
            } else {
                Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + targetAddress]);
            }
        }
    }

    function activateSelected() {
        if (root.activeMode !== "switcher") return;

        // If the user Alt+Tabs super fast before the scanner finishes, queue the activation
        if (clientScanner.running) {
            pendingActivation = true;
            return;
        }

        if (clientsModel.count > 0 && windowCarousel.currentIndex >= 0 && windowCarousel.currentIndex < clientsModel.count) {
            var item = clientsModel.get(windowCarousel.currentIndex);
            var rawAddr = item.address.trim();
            var formattedAddr = rawAddr.startsWith("0x") ? rawAddr : ("0x" + rawAddr);

            root.collapseToIdle();

            focusDelayTimer.targetAddress = formattedAddr;
            focusDelayTimer.restart();
        } else {
            root.collapseToIdle();
        }
    }

    Process {
        id: clientScanner
        running: false
        command: ["sh", "-c", `
            python3 -c "
import subprocess, json

try:
    raw = subprocess.check_output(['hyprctl', 'clients', '-j'], text=True)
    clients = json.loads(raw)
    
    # Filter valid mapped windows (workspace > 0, non-empty address)
    valid = [c for c in clients if c.get('workspace', {}).get('id', -1) > 0 and not c.get('hidden', False)]
    valid = sorted(valid, key=lambda x: x.get('focusHistoryID', 999))
    
    for c in valid:
        addr = c.get('address', '')
        title = c.get('title', 'Unknown').replace('|||', ' ')
        c_class = c.get('class', 'application-x-executable').replace('|||', ' ')
        ws = str(c.get('workspace', {}).get('id', 1))
        initial = c.get('initialClass', c_class).lower()
        size = c.get('size', [1920, 1080])
        
        print(f'{addr}|||{title}|||{c_class}|||{ws}|||{initial}|||{size[0]}|||{size[1]}')
except Exception:
    pass
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var newItems = [];
                
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 7) {
                        newItems.push({
                            "address": parts[0].trim(),
                            "title": parts[1].trim(),
                            "className": parts[2].trim(),
                            "workspace": parts[3].trim(),
                            "iconName": parts[4].trim(),
                            "winWidth": parseInt(parts[5]),
                            "winHeight": parseInt(parts[6])
                        });
                    }
                }
                
                // Prevent Carousel snap animations during the population phase
                windowCarousel.highlightMoveDuration = 0; 
                
                // Batch append to avoid rendering intermediate states
                for (var j = 0; j < newItems.length; j++) {
                    clientsModel.append(newItems[j]);
                }
                
                // Preselect previous window (index 1) immediately
                if (clientsModel.count > 0) {
                    windowCarousel.currentIndex = clientsModel.count > 1 ? 1 : 0;
                    windowCarousel.positionViewAtIndex(windowCarousel.currentIndex, PathView.Center);
                }

                restoreAnimTimer.restart();

                // If a super-fast Alt+Tab release was queued while we were scanning, trigger it now!
                if (pendingActivation) {
                    pendingActivation = false;
                    activateSelected();
                }
            }
        }
    }

    Timer {
        id: restoreAnimTimer
        interval: 60
        repeat: false
        onTriggered: windowCarousel.highlightMoveDuration = 180
    }

    // Header
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 24
        spacing: 6
        Layout.leftMargin: 8
        Layout.rightMargin: 8

        Text {
            text: "Active Windows"
            font.family: "Inter"
            font.pixelSize: 15
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
        }

        Text {
            visible: clientsModel.count > 0
            text: "(" + (windowCarousel.currentIndex + 1) + " / " + clientsModel.count + ")"
            font.pixelSize: 12
            font.bold: true
            color: Theme.colors.text_secondary ?? "#565f89"
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }
        
        Text {
            text: "Alt + Tab to cycle • Release to focus"
            font.family: "Inter"
            font.pixelSize: 11
            font.bold: true
            color: Theme.colors.accent ?? "#7aa2f7"
        }
    }

    // 3D Carousel View
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent
            // Only show 'No open windows' if we are actually done scanning
            visible: clientsModel.count === 0 && !clientScanner.running 
            text: "No open windows"
            color: Theme.colors.text_secondary ?? "#565f89"
            font.pixelSize: 13
        }

        RowLayout {
            anchors.fill: parent
            visible: clientsModel.count > 0
            spacing: 8

            Rectangle {
                id: leftArrow
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: leftArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: leftArrowMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Behavior on color { ColorAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅁"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                    color: leftArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                }
                MouseArea {
                    id: leftArrowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: windowCarousel.decrementCurrentIndex()
                }
            }

            PathView {
                id: windowCarousel
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true
                model: clientsModel

                pathItemCount: 5
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 0

                readonly property real itemWidth: Math.min(320, Math.max(180, width * 0.46))
                readonly property real itemHeight: height * 0.88

                Keys.onLeftPressed: decrementCurrentIndex()
                Keys.onRightPressed: incrementCurrentIndex()
                Keys.onReturnPressed: winSwitcher.activateSelected()
                Keys.onEnterPressed: winSwitcher.activateSelected()
                Keys.onEscapePressed: root.activeMode = "idle"

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: Qt.PointingHandCursor
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        if (wheel.angleDelta.y < 0) windowCarousel.incrementCurrentIndex();
                        else if (wheel.angleDelta.y > 0) windowCarousel.decrementCurrentIndex();
                    }
                }

                path: Path {
                    startX: -windowCarousel.itemWidth * 0.35
                    startY: windowCarousel.height / 2
                    PathAttribute { name: "itemScale"; value: 0.55 }
                    PathAttribute { name: "itemOpacity"; value: 0.0 }
                    PathAttribute { name: "itemZ"; value: 1 }
                    PathAttribute { name: "itemRotationY"; value: -42.0 }

                    PathLine { x: windowCarousel.width * 0.22; y: windowCarousel.height / 2 }
                    PathAttribute { name: "itemScale"; value: 0.80 }
                    PathAttribute { name: "itemOpacity"; value: 0.65 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemRotationY"; value: -28.0 }

                    PathLine { x: windowCarousel.width * 0.50; y: windowCarousel.height / 2 }
                    PathAttribute { name: "itemScale"; value: 1.0 }
                    PathAttribute { name: "itemOpacity"; value: 1.0 }
                    PathAttribute { name: "itemZ"; value: 30 }
                    PathAttribute { name: "itemRotationY"; value: 0.0 }

                    PathLine { x: windowCarousel.width * 0.78; y: windowCarousel.height / 2 }
                    PathAttribute { name: "itemScale"; value: 0.80 }
                    PathAttribute { name: "itemOpacity"; value: 0.65 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemRotationY"; value: 28.0 }

                    PathLine { x: windowCarousel.width + (windowCarousel.itemWidth * 0.35); y: windowCarousel.height / 2 }
                    PathAttribute { name: "itemScale"; value: 0.55 }
                    PathAttribute { name: "itemOpacity"; value: 0.0 }
                    PathAttribute { name: "itemZ"; value: 1 }
                    PathAttribute { name: "itemRotationY"; value: 42.0 }
                }

                delegate: Item {
                    id: delegateRoot
                    width: windowCarousel.itemWidth
                    height: windowCarousel.itemHeight

                    scale: PathView.itemScale ?? 0.8
                    opacity: PathView.itemOpacity ?? 0.0
                    z: PathView.itemZ ?? 1
                    visible: opacity > 0.01

                    transform: Rotation {
                        origin.x: delegateRoot.width / 2
                        origin.y: delegateRoot.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: PathView.itemRotationY ?? 0
                    }
                    
                    // Match Hyprland IPC address to Wayland Toplevel buffer
                    property var toplevel: {
                        var rawAddr = address.trim();
                        var searchAddr = rawAddr.startsWith("0x") ? rawAddr.substring(2) : rawAddr;
                        var allToplevels = typeof ToplevelManager !== "undefined" ? ToplevelManager.toplevels.values : [];
                        for (var i = 0; i < allToplevels.length; i++) {
                            if (allToplevels[i].HyprlandToplevel && allToplevels[i].HyprlandToplevel.address === searchAddr) {
                                return allToplevels[i];
                            }
                        }
                        return null;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Theme.colors.card_bg ?? "#1f2335"
                        border.width: PathView.isCurrentItem ? 2 : 1
                        border.color: PathView.isCurrentItem ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")
                        clip: true

                        // Live Native Wayland Buffer Preview
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.colors.bg ?? "#16161e"
                            
                            ScreencopyView {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height * (winWidth / Math.max(1, winHeight)))
                                height: Math.min(parent.height, parent.width / (winWidth / Math.max(1, winHeight)))
                                
                                captureSource: delegateRoot.toplevel
                                live: true

                                layer.enabled: true
                                layer.mipmap: true
                                layer.smooth: true
                                
                                // Fallback icon for windows that reject the screencopy protocol
                                Image {
                                    anchors.centerIn: parent
                                    visible: !parent.captureSource
                                    source: iconName ? ("image://icon/" + iconName) : ""
                                    sourceSize.width: 96
                                    sourceSize.height: 96
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                            }
                        }

                        // Gradient Info Overlay
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 64
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
                            }
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                anchors.bottomMargin: 10
                                spacing: 2
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    
                                    Rectangle {
                                        width: 16; height: 16; radius: 4
                                        color: Theme.colors.hover_bg ?? "#24283b"
                                        Text {
                                            anchors.centerIn: parent
                                            text: workspace
                                            font.family: "Inter"
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: Theme.colors.text_secondary ?? "#565f89"
                                        }
                                    }

                                    // App Icon Badge
                                    Image {
                                        visible: iconName !== ""
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                        source: iconName ? ("image://icon/" + iconName) : ""
                                        sourceSize.width: 16
                                        sourceSize.height: 16
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }

                                    Text {
                                        text: className
                                        color: Theme.colors.accent ?? "#7aa2f7"
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Text {
                                    text: title
                                    color: "white"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (PathView.isCurrentItem) {
                                winSwitcher.activateSelected();
                            } else {
                                windowCarousel.currentIndex = index;
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: rightArrow
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: rightArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: rightArrowMouse.containsMouse ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"
                Behavior on color { ColorAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅂"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                    color: rightArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                }
                MouseArea {
                    id: rightArrowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: windowCarousel.incrementCurrentIndex()
                }
            }
        }
    }
}
