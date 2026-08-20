import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: batteryModule
    spacing: 10
    Layout.fillWidth: true

    property int batteryLevel: 100
    property bool isCharging: false
    property real currentEnergyWh: 0
    property real fullEnergyWh: 0
    property real designEnergyWh: 0
    property real currentPowerW: 0
    property int healthPercentage: 100
    property string activeProfile: "balanced"

    readonly property bool isWarningLevel: batteryLevel <= 25 && batteryLevel > 15 && !isCharging
    readonly property bool isLowLevel: batteryLevel <= 15 && !isCharging

    readonly property color accentColor: Theme.colors.accent ?? "#7aa2f7"
    readonly property color warningColor: Theme.colors.warning ?? "#e0af68"
    readonly property color errorColor: Theme.colors.error ?? "#f44336"
    readonly property color chargingColor: "#8FDEB4"

    readonly property color statusColor: {
        if (isCharging) return chargingColor;
        if (isLowLevel) return errorColor;
        if (isWarningLevel) return warningColor;
        return accentColor;
    }

    Process {
        id: battDetailScanner
        running: root.activeMode === "battery" || root.activeMode === "hover" || root.activeMode === "idle"
        command: ["sh", "-c", `
            python3 -c "
import glob, os

bats = [b for b in glob.glob('/sys/class/power_supply/*') if os.path.exists(os.path.join(b, 'type')) and open(os.path.join(b, 'type')).read().strip() == 'Battery']
if not bats:
    print('100|||Not Charging|||0.0|||0.0|||0.0|||100|||0.0')
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
p_now = read_num('power_now')

v_design = read_num('voltage_min_design') or 11500000.0

if e_full is None or e_design is None or e_design == 0:
    c_now = read_num('charge_now') or 0.0
    c_full = read_num('charge_full') or 0.0
    c_design = read_num('charge_full_design') or 0.0
    c_power = read_num('current_now') or 0.0
    
    e_now = (c_now * v_design) / 1e12
    e_full = (c_full * v_design) / 1e12
    e_design = (c_design * v_design) / 1e12
    p_now = (c_power * v_design) / 1e12
else:
    e_now = e_now / 1e6
    e_full = e_full / 1e6
    e_design = e_design / 1e6
    p_now = (p_now or 0.0) / 1e6

if e_design > 0:
    health = int(round((e_full / e_design) * 100))
else:
    health = 100

print(f'{cap}|||{status}|||{e_now:.1f}|||{e_full:.1f}|||{e_design:.1f}|||{health}|||{p_now:.1f}')
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
                    batteryModule.currentPowerW = parseFloat(p[6]) || 0;
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

    Timer {
        interval: 250
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

    // Hero Metric Card
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 120
        radius: 12
        color: Theme.colors.card_bg ?? "#1f2335"
        border.width: 1
        border.color: Theme.colors.border ?? "#16161e"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 14

            Item {
                Layout.preferredWidth: 88
                Layout.preferredHeight: 88
                Layout.alignment: Qt.AlignVCenter

                Canvas {
                    id: batteryDial
                    anchors.fill: parent

                    property real level: batteryModule.batteryLevel
                    property color dialColor: batteryModule.statusColor
                    property color trackColor: Qt.rgba(1, 1, 1, 0.07)

                    onLevelChanged: requestPaint()
                    onDialColorChanged: requestPaint()
                    Connections {
                        target: Theme
                        function onColorsChanged() { batteryDial.requestPaint(); }
                    }
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var cx = width / 2;
                        var cy = height / 2;
                        var r = Math.min(width, height) / 2 - 6;

                        ctx.lineWidth = 6;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                        ctx.strokeStyle = trackColor;
                        ctx.stroke();

                        var startAngle = -Math.PI / 2;
                        var endAngle = startAngle + (2 * Math.PI * (level / 100.0));
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, startAngle, endAngle, false);
                        ctx.strokeStyle = dialColor;
                        ctx.stroke();
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: -2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: batteryModule.batteryLevel + "%"
                        font.family: "Inter"
                        font.pixelSize: 20
                        font.bold: true
                        font.features: { "tnum": 1 }
                        color: Theme.colors.text_primary ?? "white"
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: batteryModule.isCharging ? "Charging" : (batteryModule.isLowLevel ? "Low" : "Battery")
                        font.family: "Inter"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: batteryModule.statusColor
                    }
                }

                Rectangle {
                    width: 20; height: 20; radius: 10
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.rightMargin: -1; anchors.bottomMargin: -1
                    color: batteryModule.statusColor
                    border.width: 2
                    border.color: Theme.colors.card_bg ?? "#1f2335"

                    Text {
                        anchors.centerIn: parent
                        text: batteryModule.isCharging ? "󱐋" : (batteryModule.isLowLevel ? "!" : "󰁹")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.colors.bg ?? "#16161e"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    
                    Column {
                        spacing: 1
                        Text {
                            text: batteryModule.isCharging ? "AC Power Connected" : "Battery Discharging"
                            font.family: "Inter"
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.colors.text_primary ?? "white"
                        }
                        Text {
                            text: (batteryModule.currentPowerW > 0 ? batteryModule.currentPowerW.toFixed(1) + " W rate • " : "") + batteryModule.currentEnergyWh.toFixed(1) + " Wh remaining"
                            font.family: "Inter"
                            font.pixelSize: 10
                            color: Theme.colors.text_secondary ?? "#565f89"
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Battery Health"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Theme.colors.text_secondary ?? "#565f89"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: batteryModule.healthPercentage + "%"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.bold: true
                            color: batteryModule.healthPercentage > 75 ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.error ?? "#f44336")
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: Theme.colors.bg ?? "#16161e"
                        clip: true

                        Rectangle {
                            width: parent.width * (batteryModule.healthPercentage / 100.0)
                            height: parent.height
                            radius: 2
                            color: batteryModule.healthPercentage > 75 ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.error ?? "#f44336")
                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                        }
                    }
                }

                Text {
                    text: batteryModule.fullEnergyWh.toFixed(1) + " Wh capacity / " + batteryModule.designEnergyWh.toFixed(1) + " Wh design"
                    font.family: "Inter"
                    font.pixelSize: 9
                    color: Theme.colors.text_secondary ?? "#565f89"
                    opacity: 0.8
                }
            }
        }
    }

    // Power Profiles Pill Control
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Power Profile"
            font.family: "Inter"
            font.pixelSize: 11
            font.bold: true
            color: Theme.colors.text_secondary ?? "#565f89"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 19
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
                        radius: 16
                        property bool isSelected: batteryModule.activeProfile === modelData.profile
                        color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : "transparent"
                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: isSelected ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_secondary ?? "#565f89")
                            }
                            Text {
                                text: modelData.text
                                font.family: "Inter"
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
