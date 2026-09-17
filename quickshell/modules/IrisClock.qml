import QtQuick
import "../"

// The iRiS time figure: tabular hours and minutes, a separator tinted
// with the secondary accent (orange), and optional seconds / AM-PM.
Row {
    id: root

    property string text: ""
    property real pixelSize: 15
    property int weight: Font.Bold
    property color color: Theme.colors.text_primary ?? "#f5f5f7"
    property color separatorColor: Theme.colors.accent ?? "#a8c7fa"
    property string family: "Rubik"
    property real minorScale: 0.58
    property bool isScreenRecording: false

    baselineOffset: hoursText.baselineOffset

    readonly property var parts: {
        const raw = String(root.text ?? "").trim();
        const period = raw.match(/\s*([^\d:.\s]+)$/);
        const figure = period ? raw.slice(0, period.index) : raw;
        const pieces = figure.split(/[:.]/);
        return {
            hours: pieces[0] ?? "",
            minutes: pieces[1] ?? "",
            seconds: pieces[2] ?? "",
            period: period ? period[1] : ""
        };
    }

    spacing: 0

    component Figure: Text {
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.features: ({ "tnum": 1 })
        font.letterSpacing: -root.pixelSize * 0.02
        color: root.color
        renderType: Text.NativeRendering
    }

    component Minor: Text {
        font.family: root.family
        font.pixelSize: Math.round(root.pixelSize * root.minorScale)
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
        color: Qt.alpha(root.color, 0.55)
        renderType: Text.NativeRendering
    }

    // Hours, minutes and seconds count; the separator and period stay put.
    IrisNumber {
        id: hoursText
        text: root.parts.hours
        family: root.family
        pixelSize: root.pixelSize
        weight: root.weight
        letterSpacing: -root.pixelSize * 0.02
        color: root.color
    }

    Figure {
        text: ":"
        visible: root.parts.minutes.length > 0
        color: root.separatorColor
        anchors.baseline: hoursText.baseline
        anchors.baselineOffset: -root.pixelSize * 0.06
        leftPadding: root.pixelSize * 0.03
        rightPadding: root.pixelSize * 0.03
    }

    IrisNumber {
        text: root.parts.minutes
        anchors.baseline: hoursText.baseline
        family: root.family
        pixelSize: root.pixelSize
        weight: root.weight
        letterSpacing: -root.pixelSize * 0.02
        color: root.color
    }

    Item {
        visible: root.parts.seconds.length > 0
        implicitWidth: secondsText.implicitWidth + root.pixelSize * 0.12
        implicitHeight: secondsText.implicitHeight
        baselineOffset: secondsText.baselineOffset
        anchors.baseline: hoursText.baseline
        IrisNumber {
            id: secondsText
            anchors.right: parent.right
            text: root.parts.seconds
            family: root.family
            pixelSize: Math.round(root.pixelSize * root.minorScale)
            weight: Font.DemiBold
            color: Qt.alpha(root.color, 0.55)
        }
    }

    Minor {
        visible: root.parts.period.length > 0
        text: root.parts.period
        leftPadding: root.pixelSize * 0.16
        anchors.baseline: hoursText.baseline
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 6
        width: 7; height: 7; radius: 3.5
        color: "#ff6961"
        visible: root.isScreenRecording

        SequentialAnimation on opacity {
            running: root.isScreenRecording
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.2; duration: 800; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.2; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
        }
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text
}
