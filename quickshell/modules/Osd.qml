import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: osdModule
    Layout.fillWidth: true
    Layout.fillHeight: true

    // Smooth normalized value interpolation (0 to 100)
    property real animatedValue: root.osdValue
    Behavior on animatedValue {
        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // Left Icon
        Item {
            Layout.preferredWidth: 24
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: {
                    if (root.osdType === "brightness") {
                        return osdModule.animatedValue < 35 ? "󰃞" : (osdModule.animatedValue < 70 ? "󰃟" : "󰃠");
                    }
                    if (root.osdValue <= 0) return "󰖁";
                    if (osdModule.animatedValue < 40) return "󰕿";
                    if (osdModule.animatedValue < 70) return "󰖀";
                    return "󰕾";
                }
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: (root.osdType !== "brightness" && root.osdValue <= 0) ? "#f7768e" : (Theme.colors.accent ?? "#7aa2f7")
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        // Center Track & Smooth Liquid Fill Bar
        Rectangle {
            id: osdTrack
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            Layout.alignment: Qt.AlignVCenter
            radius: 4
            color: Theme.colors.hover_bg ?? "#24283b"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                // Width is purely proportional to the smoothly interpolated percentage:
                // Evaluated directly from track width to prevent layout fights and jitter.
                width: Math.max(0, Math.min(osdTrack.width, osdTrack.width * (osdModule.animatedValue / 100.0)))
                radius: 4
                color: (root.osdType !== "brightness" && root.osdValue <= 0) ? "#f7768e" : (Theme.colors.accent ?? "#7aa2f7")
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        // Right Percentage Label
        Item {
            Layout.preferredWidth: 38
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(osdModule.animatedValue) + "%"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true
                font.features: { "tnum": 1 }
                color: Theme.colors.text_primary ?? "#c0caf5"
            }
        }
    }
}
