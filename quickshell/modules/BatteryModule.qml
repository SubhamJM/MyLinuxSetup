import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: batteryModule
    spacing: 10

    property int batteryLevel: 100
    property bool isCharging: false
    property real currentEnergyWh: 0
    property real fullEnergyWh: 0
    property real designEnergyWh: 0
    property int healthPercentage: 100
    property string activeProfile: "balanced"

    readonly property bool isWarningLevel: batteryLevel <= 25 && batteryLevel > 15 && !isCharging
    readonly property bool isLowLevel: batteryLevel <= 15 && !isCharging

    function batteryIcon(lvl, charging) {
        if (charging) return "󱐋";
        if (lvl <= 15) return "󰁺";
        if (lvl <= 30) return "󰁻";
        if (lvl <= 45) return "󰁼";
        if (lvl <= 60) return "󰁽";
        if (lvl <= 75) return "󰁾";
        if (lvl <= 90) return "󰂀";
        return "󰁹";
    }

    readonly property color statusColor: {
        if (isCharging) return Theme.colors.accent ?? "#7aa2f7";
        if (isLowLevel) return Theme.colors.error ?? "#f44336";
        if (isWarningLevel) return Theme.colors.warning ?? "#e0af68";
        return Theme.colors.accent ?? "#7aa2f7";
    }

    Process {
        id: battDetailScanner
        running: root.activeMode === "battery" || root.activeMode === "hover" || root.activeMode === "idle"
        command: ["sh", "-c", `
            python3 -c "
import glob, os

bats = [b for b in glob.glob('/sys/class/power_supply/*') if os.path.exists(os.path.join(b, 'type')) and open(os.path.join(b, 'type')).read().strip() == 'Battery']
if not bats:
    print('100|||Not Charging|||0.0|||0.0|||0.0|||100')
    exit()

bat = bats[0]

def read_num(name):
    p = os.path.join(bat, name)
    if os.path.exists(p):
        try:
            with open(p, 'r') as f:
                return float(f.read().strip())
        except:
            pass
    return None

def read_str(name, default=''):
    p = os.path.join(bat, name)
    if os.path.exists(p):
        try:
            with open(p, 'r') as f:
                return f.read().strip()
        except:
            pass
    return default

cap = int(read_num('capacity') or 100)
status = read_str('status', 'Discharging')

e_now = read_num('energy_now')
e_full = read_num('energy_full')
e_design = read_num('energy_full_design')

v_design = read_num('voltage_min_design') or 11500000.0

if e_full is None or e_design is None or e_design == 0:
    c_now = read_num('charge_now') or 0.0
    c_full = read_num('charge_full') or 0.0
    c_design = read_num('charge_full_design') or 0.0
    
    e_now = (c_now * v_design) / 1e12
    e_full = (c_full * v_design) / 1e12
    e_design = (c_design * v_design) / 1e12
else:
    e_now = e_now / 1e6
    e_full = e_full / 1e6
    e_design = e_design / 1e6

if e_design > 0:
    health = int(round((e_full / e_design) * 100))
else:
    health = 100

print(f'{cap}|||{status}|||{e_now:.1f}|||{e_full:.1f}|||{e_design:.1f}|||{health}')
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                if (lines.length > 0 && lines[0].includes("|||")) {
                    var p = lines[0].split("|||");
                    batteryModule.batteryLevel = parseInt(p[0]) || 100;
                    batteryModule.isCharging = (p[1] === "Charging");
                    batteryModule.currentEnergyWh = parseFloat(p[2]) || 0;
                    batteryModule.fullEnergyWh = parseFloat(p[3]) || 0;
                    batteryModule.designEnergyWh = parseFloat(p[4]) || 0;
                    batteryModule.healthPercentage = Math.min(100, Math.max(0, parseInt(p[5]) || 100));
                }
            }
        }
    }

    Process {
        id: profileChecker
        running: root.activeMode === "battery"
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null || echo 'balanced'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var profile = this.text.trim();
                if (profile !== "") batteryModule.activeProfile = profile;
            }
        }
    }

    // 1-second update interval for real-time responsiveness
    Timer {
        interval: 1000
        running: root.activeMode === "battery" || root.activeMode === "hover" || root.activeMode === "idle"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!battDetailScanner.running) battDetailScanner.running = true;
            if (root.activeMode === "battery" && !profileChecker.running) profileChecker.running = true;
        }
    }

    function setProfile(profileName) {
        batteryModule.activeProfile = profileName;
        Quickshell.execDetached(["powerprofilesctl", "set", profileName]);
    }

    // // ==========================================
    // // STATUS CARD — Android Settings-style circular
    // // battery ring, percentage centered inside it
    // // instead of a separate top badge.
    // // ==========================================
    // Rectangle {
    //     Layout.fillWidth: true; Layout.preferredHeight: 138; radius: 20
    //     color: Theme.colors.card_bg ?? "#1f2335"
    //     border.width: 1; border.color: Theme.colors.border ?? "#16161e"

    //     ColumnLayout {
    //         anchors.fill: parent
    //         anchors.margins: 10
    //         spacing: 6

    //         Item {
    //             Layout.alignment: Qt.AlignHCenter
    //             Layout.preferredWidth: 84
    //             Layout.preferredHeight: 84

    //             Canvas {
    //                 id: batteryRing
    //                 anchors.fill: parent

    //                 property real level: batteryModule.batteryLevel
    //                 property color ringColor: batteryModule.statusColor
    //                 property color trackColor: {
    //                     var t = Theme.colors.text_secondary ?? "#565f89";
    //                     return Qt.rgba(t.r, t.g, t.b, 0.18);
    //                 }

    //                 onLevelChanged: requestPaint()
    //                 onRingColorChanged: requestPaint()
    //                 Connections { target: Theme; function onColorsChanged() { batteryRing.requestPaint() } }
    //                 Component.onCompleted: requestPaint()

    //                 onPaint: {
    //                     var ctx = getContext("2d");
    //                     ctx.reset();
    //                     var cx = width / 2, cy = height / 2, r = Math.min(width, height) / 2 - 5;

    //                     ctx.lineWidth = 7;
    //                     ctx.lineCap = "round";

    //                     ctx.beginPath();
    //                     ctx.arc(cx, cy, r, 0, 2 * Math.PI);
    //                     ctx.strokeStyle = trackColor;
    //                     ctx.stroke();

    //                     var startAngle = -Math.PI / 2;
    //                     var endAngle = startAngle + (2 * Math.PI * (level / 100));
    //                     ctx.beginPath();
    //                     ctx.arc(cx, cy, r, startAngle, endAngle, false);
    //                     ctx.strokeStyle = ringColor;
    //                     ctx.stroke();
    //                 }
    //             }

    //             ColumnLayout {
    //                 anchors.centerIn: parent
    //                 spacing: -2
    //                 Text {
    //                     Layout.alignment: Qt.AlignHCenter
    //                     text: batteryModule.batteryLevel + "%"
    //                     font.pixelSize: 21; font.bold: true
    //                     color: Theme.colors.text_primary ?? "white"
    //                 }
    //             }

    //             // Charging badge, overlaid bottom-right of the ring —
    //             // mirrors Android's small bolt overlay on the battery icon.
    //             Rectangle {
    //                 visible: batteryModule.isCharging
    //                 width: 26; height: 26; radius: 13
    //                 anchors.right: parent.right
    //                 anchors.bottom: parent.bottom
    //                 anchors.rightMargin: -2
    //                 anchors.bottomMargin: -2
    //                 color: batteryModule.statusColor
    //                 border.width: 3
    //                 border.color: Theme.colors.card_bg ?? "#1f2335"
    //                 Text {
    //                     anchors.centerIn: parent
    //                     text: "󱐋"
    //                     font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
    //                     color: Theme.colors.bg ?? "#16161e"
    //                 }
    //             }
    //         }

    //         ColumnLayout {
    //             Layout.alignment: Qt.AlignHCenter
    //             spacing: 1

    //             Text {
    //                 Layout.alignment: Qt.AlignHCenter
    //                 text: batteryModule.isCharging ? "Charging" : (batteryModule.isWarningLevel || batteryModule.isLowLevel ? "Low battery" : "On battery")
    //                 font.pixelSize: 13; font.bold: true
    //                 color: batteryModule.statusColor

    //                 SequentialAnimation on opacity {
    //                     running: batteryModule.isLowLevel
    //                     loops: Animation.Infinite
    //                     NumberAnimation { to: 0.4; duration: 500 }
    //                     NumberAnimation { to: 1.0; duration: 500 }
    //                 }
    //             }
    //             Text {
    //                 Layout.alignment: Qt.AlignHCenter
    //                 text: batteryModule.currentEnergyWh.toFixed(1) + " Wh remaining"
    //                 font.pixelSize: 11
    //                 color: Theme.colors.text_secondary ?? "#565f89"
    //             }
    //         }
    //     }
    // }

    // Health Card
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: 14
        color: Theme.colors.card_bg ?? "#1f2335"
        border.width: 1
        border.color: Theme.colors.border ?? "#16161e"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Battery Health"
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.colors.text_primary ?? "white"
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: batteryModule.fullEnergyWh.toFixed(1) + " Wh / " + batteryModule.designEnergyWh.toFixed(1) + " Wh (" + batteryModule.healthPercentage + "%)"
                    font.pixelSize: 11
                    font.bold: true
                    color: batteryModule.healthPercentage > 75 ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.error ?? "#f44336")
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 5
                radius: 2.5
                color: Theme.colors.bg ?? "#16161e"
                clip: true

                Rectangle {
                    width: parent.width * (batteryModule.healthPercentage / 100.0)
                    height: parent.height
                    radius: 2.5
                    color: batteryModule.healthPercentage > 75 ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.error ?? "#f44336")
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }
            }
        }
    }

    // Power Profiles — Android-style segmented pill control, same
    // pattern as the Wi-Fi / Hotspot tab switcher in WifiModule.qml.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Power Profile"
            font.pixelSize: 11
            font.bold: true
            color: Theme.colors.text_secondary ?? "#565f89"
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 22
            color: Theme.colors.hover_bg ?? "#24283b"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 3

                Repeater {
                    model: [
                        { text: "Saver",       icon: "󰌪", profile: "power-saver" },
                        { text: "Balanced",    icon: "󰾅", profile: "balanced" },
                        { text: "Performance", icon: "󰓅", profile: "performance" }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 19
                        property bool isSelected: batteryModule.activeProfile === modelData.profile
                        color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : "transparent"
                        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: isSelected ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_secondary ?? "#565f89")
                            }
                            Text {
                                text: modelData.text
                                font.bold: true
                                font.pixelSize: 11
                                color: isSelected ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: batteryModule.setProfile(modelData.profile)
                        }
                    }
                }
            }
        }
    }
}
