import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: osdModule
    Layout.fillWidth: true
    Layout.fillHeight: true

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 12

        Text {
            text: root.osdType === "brightness" ? "󰃠" : (root.osdValue <= 0 ? "󰖁" : (root.osdValue > 60 ? "󰕾" : "󰖀"))
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: Theme.colors.accent ?? "#7aa2f7"
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
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            text: root.osdValue + "%"
            font.pixelSize: 12
            font.bold: true
            color: Theme.colors.text_primary ?? "#c0caf5"
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: 32
            horizontalAlignment: Text.AlignRight
        }
    }
}
