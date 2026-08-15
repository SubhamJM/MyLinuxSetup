import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: osdModule
    Layout.fillWidth: true
    Layout.fillHeight: true

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 16

        Text {
            text: root.osdType === "brightness" ? "󰃠" : (root.osdValue == 0 ? "󰖁" : "󰕾")
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: Theme.colors.text_primary ?? "#c0caf5"
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            id: osdTrack
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            height: 6
            radius: 3
            color: Theme.colors.hover_bg ?? "#24283b"
            clip: true

            Rectangle {
                width: osdTrack.width * (root.osdValue / 100.0)
                height: parent.height
                radius: 3
                color: Theme.colors.accent ?? "#7aa2f7"

                Behavior on width {
                    enabled: root.osdReady
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            text: root.osdValue + "%"
            font.pixelSize: 13
            font.bold: true
            color: Theme.colors.text_primary ?? "#c0caf5"
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: 35
            horizontalAlignment: Text.AlignRight
        }
    }
}
