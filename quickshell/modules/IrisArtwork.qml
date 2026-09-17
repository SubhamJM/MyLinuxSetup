import QtQuick
import Qt5Compat.GraphicalEffects
import "../"

Item {
    id: root
    property string source: ""
    property bool circular: true
    property real radius: circular ? width / 2 : 6
    property real decodeSize: 0
    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    Image {
        id: cover
        anchors.fill: parent
        source: root.source
        sourceSize: root.decodeSize > 0 ? Qt.size(Math.ceil(root.decodeSize), Math.ceil(root.decodeSize))
            : Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        source: cover
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
            color: "white"
        }
        visible: cover.status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        visible: cover.status !== Image.Ready
        text: "󰎆"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.width * 0.5
        color: Theme.colors.accent ?? "#88c0d0"
    }
}
