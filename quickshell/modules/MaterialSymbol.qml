import QtQuick

Text {
    id: root
    property real iconSize: 18
    property real fill: 0
    color: "#f5f5f7"

    readonly property bool isNerd: text.length > 0 && text.charCodeAt(0) >= 0xE000
    font.family: isNerd ? "JetBrainsMono Nerd Font" : "Material Symbols Rounded"
    font.pixelSize: iconSize
    font.variableAxes: isNerd ? ({}) : ({ "FILL": fill, "opsz": 24 })
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
