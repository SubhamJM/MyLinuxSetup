import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: transModule
    spacing: 12

    property alias transitionGrid: transitionGrid
    property var allTransitions: ["simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "outer", "random"]
    ListModel { id: transitionModel }

    Component.onCompleted: {
        transitionModel.clear();
        for (var i = 0; i < allTransitions.length; i++) {
            transitionModel.append({"transitionName": allTransitions[i]});
        }
    }

    Process { 
        id: transitionWriter
        running: false
        onExited: Theme.reload()
    }

    Text {
        text: "Wallpaper Transitions"
        font.pixelSize: 16
        font.bold: true
        color: Theme.colors.text_primary ?? "white"
        Layout.alignment: Qt.AlignHCenter
    }

    GridView {
        id: transitionGrid
        focus: true
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: width / 2
        cellHeight: 45
        model: transitionModel

        Keys.onEscapePressed: root.activeMode = "idle"
        Keys.onLeftPressed: if (currentIndex > 0) currentIndex--
        Keys.onRightPressed: if (currentIndex < count - 1) currentIndex++
        Keys.onUpPressed: if (currentIndex - 2 >= 0) currentIndex -= 2
        Keys.onDownPressed: if (currentIndex + 2 < count) currentIndex += 2
        Keys.onReturnPressed: applyTransition(currentIndex)
        Keys.onEnterPressed: applyTransition(currentIndex)

        function applyTransition(idx) {
            if (idx >= 0 && idx < count) {
                var trans = transitionModel.get(idx).transitionName;
                if (transitionWriter.running) transitionWriter.running = false;
                transitionWriter.command = [
                    "sh", "-c", 
                    "mkdir -p $HOME/.config/active-theme && echo -n '" + trans + "' > $HOME/.config/active-theme/wallpaper-transition.txt"
                ];
                transitionWriter.running = true;
                root.activeMode = "idle";
            }
        }

        delegate: Item {
            width: GridView.view.cellWidth
            height: GridView.view.cellHeight
            property bool isCurrent: transitionName === Theme.activeTransition
            property bool isSelected: GridView.isCurrentItem

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: isSelected ? (Theme.colors.hover_bg ?? "#24283b") : (transMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (isCurrent ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335")))
                border.color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (isCurrent ? (Theme.colors.accent ?? "#7aa2f7") : (transMouse.containsMouse ? (Theme.colors.border_hover ?? "#7aa2f7") : (Theme.colors.border ?? "#16161e")))
                border.width: isSelected || isCurrent ? 2 : 1
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: transitionName + (isCurrent ? " ✓" : "")
                    color: isSelected || isCurrent || transMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "white")
                    font.pixelSize: 13
                    font.bold: true
                }

				MouseArea {
					id: transMouse
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onEntered: transitionGrid.currentIndex = index
					onClicked: transitionGrid.applyTransition(index)
				}
            }
        }
    }
}
