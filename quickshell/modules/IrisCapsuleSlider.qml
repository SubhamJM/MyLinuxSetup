import QtQuick
import "../"

// Authentic Inir Iris Capsule Slider: vertical / horizontal thick capsule
// with fill level and contrasting Material symbol living inside the foot.
Item {
    id: root

    property real value: 0
    property string icon: "volume_up"
    property bool muted: false
    property bool vertical: true
    property color fillColor: Theme.colors.accent ?? "#88c0d0"
    property color trackColor: Qt.rgba(1, 1, 1, 0.08)

    signal moved(real value)
    signal iconClicked()

    property real dragValue: -1
    readonly property real shownValue: Math.max(0, Math.min(1, root.dragValue >= 0 ? root.dragValue : root.value))
    readonly property real thickness: root.vertical ? root.width : root.height
    readonly property real span: root.vertical ? root.height : root.width

    implicitWidth: root.vertical ? 48 : 240
    implicitHeight: root.vertical ? 116 : 44

    Rectangle {
        id: track
        anchors.fill: parent
        radius: root.thickness / 2
        color: root.trackColor
        scale: pointer.pressed ? 1.02 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Item {
            id: fillClip
            property real length: root.span * root.shownValue
            Behavior on length {
                enabled: root.dragValue < 0
                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
            }
            y: root.vertical ? track.height - fillClip.length : 0
            width: root.vertical ? track.width : fillClip.length
            height: root.vertical ? fillClip.length : track.height
            clip: true

            Rectangle {
                y: -fillClip.y
                width: track.width
                height: track.height
                radius: root.thickness / 2
                color: root.muted ? Qt.rgba(1, 1, 1, 0.25) : root.fillColor
            }
        }

        MaterialSymbol {
            readonly property real pocket: (root.thickness - iconSize) / 2
            x: pocket
            y: root.vertical ? track.height - root.thickness + pocket : pocket
            text: root.icon
            fill: 1
            iconSize: 20
            readonly property bool overFill: !root.muted && fillClip.length >= root.thickness * 0.72
            color: overFill ? "#000000" : (Theme.colors.text_primary ?? "#ffffff")
            Behavior on color { ColorAnimation { duration: 110 } }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function valueAt(mouse) {
            return Math.max(0, Math.min(1, root.vertical ? 1 - mouse.y / Math.max(1, height) : mouse.x / Math.max(1, width)));
        }

        function inPocket(mouse) {
            return root.vertical ? mouse.y > height - root.thickness : mouse.x < root.thickness;
        }

        onPressed: (mouse) => {
            if (inPocket(mouse)) return;
            root.dragValue = valueAt(mouse);
            root.moved(root.dragValue);
        }

        onPositionChanged: (mouse) => {
            if (!pressed || root.dragValue < 0) return;
            root.dragValue = valueAt(mouse);
            root.moved(root.dragValue);
        }

        onReleased: (mouse) => {
            if (root.dragValue < 0 && inPocket(mouse)) {
                root.iconClicked();
            }
            root.dragValue = -1;
        }

        onCanceled: root.dragValue = -1

        onWheel: (wheel) => {
            var delta = (wheel.angleDelta.y || wheel.angleDelta.x) / 120.0;
            root.moved(Math.max(0, Math.min(1, root.value + delta * 0.05)));
        }
    }
}
