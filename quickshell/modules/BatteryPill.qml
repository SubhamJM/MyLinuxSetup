import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import Quickshell.Services.UPower
import "../../../services" as QsServices
import "../../../components/effects"
import "../"

// Android-style animated battery, with a quickshell/caelestia-flavoured expanded charge pill
Item {
    id: root

    implicitWidth: batteryContainer.width
    implicitHeight: 24

    readonly property var battery: UPower.displayDevice
    readonly property var powerProfiles: QsServices.PowerProfiles
    readonly property var pywal: QsServices.Pywal
    readonly property real percentage: battery?.percentage ?? 0
    readonly property int batteryLevel: Math.round(percentage * 100)
    readonly property bool isCharging: battery?.state === UPowerDevice.Charging
    readonly property bool isFullyCharged: battery?.state === UPowerDevice.FullyCharged
    readonly property bool isPluggedIn: isCharging || isFullyCharged
    readonly property bool isWarning: batteryLevel <= 25 && batteryLevel > 15
    readonly property bool isLow: batteryLevel <= 15
    readonly property bool isCritical: isLow && !isPluggedIn

    // Caelestia-flavoured "emphasized decelerate" motion curve — smooth, no bounce.
    // (Material 3 emphasized-decelerate: cubic-bezier(0.05, 0.7, 0.1, 1))
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    // Track state changes for animations
    property bool wasPluggedIn: false
    property bool showExpandedMode: false
    property bool justPluggedIn: false

    // Detect plug-in event
    onIsPluggedInChanged: {
        if (isPluggedIn && !wasPluggedIn) {
            // Just plugged in - trigger expansion animation
            justPluggedIn = true
            showExpandedMode = true
            liquidFillAnim.restart()
            expandTimer.restart()
        }
        wasPluggedIn = isPluggedIn
    }

    // Timer to collapse back after showing liquid fill
    Timer {
        id: expandTimer
        interval: 4000
        onTriggered: {
            showExpandedMode = false
            justPluggedIn = false
        }
    }

    // Colors
    readonly property color normalColor: {
        if (isLow) return pywal.error ?? "#f44336"
        if (isWarning) return pywal.warning ?? "#e0af68"
        return Theme.colors.text_primary ?? "#c0caf5"
    }

    readonly property color chargingColor: "#8FDEB4"
    readonly property color liquidColor: Qt.lighter("#8FDEB4", 1.2)
    readonly property color compactBatteryColor: {
        if (showExpandedMode || justPluggedIn) return chargingColor
        if (isPluggedIn && (isLow || isWarning)) return normalColor
        if (isPluggedIn) return chargingColor
        return normalColor
    }

    // Main container
    Item {
        id: batteryContainer
        anchors.centerIn: parent
        width: showExpandedMode ? expandedPill.width : normalBattery.width
        height: 20

        Behavior on width {
            NumberAnimation {
                duration: 420
                easing.type: Easing.BezierCurve
                easing.bezierCurve: root.motionCurve
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // STATE 1 & 3: Normal / Charging compact view — macOS style
        // ═══════════════════════════════════════════════════════════════
        Row {
            id: normalBattery
            anchors.centerIn: parent
            spacing: 6
            visible: !showExpandedMode
            opacity: showExpandedMode ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.BezierCurve; easing.bezierCurve: root.motionCurve }
            }

            // Percentage text
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: batteryLevel + "%"
                font.family: "Inter"
                font.pixelSize: 12
                font.weight: (isWarning || isLow) ? Font.Bold : Font.Medium
                color: compactBatteryColor

                Behavior on color {
                    ColorAnimation { duration: 280 }
                }

                // Critical pulse
                SequentialAnimation on opacity {
                    running: isCritical
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.0; duration: 500 }
                    NumberAnimation { to: 0.3; duration: 500 }
                }
            }

            // Battery icon — macOS Golden Gate style
            Item {
                width: 26
                height: 12
                anchors.verticalCenter: parent.verticalCenter

                // Battery body
                Rectangle {
                    id: batteryBody
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 23
                    height: 12
                    radius: 3.5
                    color: "transparent"
                    border.width: 1.2
                    border.color: compactBatteryColor

                    Behavior on border.color {
                        ColorAnimation { duration: 280 }
                    }

                    // Fill level — macOS style inner rounded fill
                    Rectangle {
                        id: fillRect
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 1.5
                        width: Math.max(0, (parent.width - 3) * root.percentage)
                        radius: 2
                        color: compactBatteryColor

                        Behavior on width {
                            NumberAnimation { duration: 450; easing.type: Easing.BezierCurve; easing.bezierCurve: root.motionCurve }
                        }

                        // Charging shimmer
                        Rectangle {
                            id: chargeShimmer
                            visible: isCharging && !isFullyCharged && !showExpandedMode
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(1, 1, 1, 0.12)
                            opacity: 0

                            property real shimmerPos: 0
                            x: (parent.width + width) * shimmerPos - width

                            SequentialAnimation on shimmerPos {
                                running: isCharging && !isFullyCharged && !showExpandedMode
                                loops: Animation.Infinite
                                NumberAnimation { from: -0.3; to: 1.3; duration: 1200; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: 400 }
                            }

                            SequentialAnimation on opacity {
                                running: isCharging && !isFullyCharged && !showExpandedMode
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.04; to: 0.16; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.16; to: 0.04; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }

                // Terminal nub — macOS style
                Rectangle {
                    anchors.left: batteryBody.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2.5
                    height: 4
                    radius: 1
                    color: compactBatteryColor

                    Behavior on color {
                        ColorAnimation { duration: 280 }
                    }
                }

                // Charging bolt icon
                Text {
                    visible: isPluggedIn && !showExpandedMode
                    anchors.centerIn: batteryBody
                    text: "󱐋"
                    font.family: "Material Design Icons"
                    font.pixelSize: 11
                    color: Theme.colors.bg ?? "#16161e"
                    opacity: 0.9

                    SequentialAnimation on scale {
                        running: isCharging && !isFullyCharged && !showExpandedMode
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.2; duration: 400; easing.type: Easing.OutCubic }
                        NumberAnimation { to: 1.0; duration: 400; easing.type: Easing.InCubic }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // STATE 2: Just plugged in — quickshell-style charge pill
        // Dark island background + accent glow + underline progress,
        // matching the rest of the shell instead of a default solid-fill capsule.
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            id: expandedPill
            anchors.centerIn: parent
            width: pillRow.implicitWidth + 26
            height: 22
            radius: 11
            visible: showExpandedMode
            opacity: showExpandedMode ? 1 : 0
            color: Qt.rgba(pywal.surfaceDim.r, pywal.surfaceDim.g, pywal.surfaceDim.b, 0.94)
            border.width: 1
            border.color: Qt.rgba(chargingColor.r, chargingColor.g, chargingColor.b, 0.45)

            Behavior on opacity {
                NumberAnimation { duration: 260; easing.type: Easing.BezierCurve; easing.bezierCurve: root.motionCurve }
            }

            // Soft breathing glow ring — subtle, not bouncy
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: chargingColor
                opacity: 0

                SequentialAnimation on opacity {
                    running: showExpandedMode
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.0; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.35; to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            Row {
                id: pillRow
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                spacing: 6

                Text {
                    text: ""
                    font.family: "Material Design Icons"
                    font.pixelSize: 13
                    color: chargingColor
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on scale {
                        running: showExpandedMode
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.15; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    text: batteryLevel + "%"
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: Theme.colors.text_primary ?? "#c0caf5"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Progress underline — fills to charge level instead of a full solid capsule
            Rectangle {
                id: underlineTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                height: 2
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    id: liquidFillBg
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 0
                    radius: parent.radius
                    color: chargingColor

                    // Liquid fill animation
                    SequentialAnimation {
                        id: liquidFillAnim

                        NumberAnimation {
                            target: liquidFillBg
                            property: "width"
                            from: 0
                            to: underlineTrack.width * root.percentage
                            duration: 900
                            easing.type: Easing.BezierCurve
                            easing.bezierCurve: root.motionCurve
                        }
                    }
                }
            }
        }
    }
}
