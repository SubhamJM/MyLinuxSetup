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

# Lock calculations to nominal design voltage to eliminate live fluctuating drops
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

    Timer {
        interval: 3000
        running: root.activeMode === "battery" || root.activeMode === "hover"
        repeat: true
        onTriggered: {
            if (!battDetailScanner.running) battDetailScanner.running = true;
            if (root.activeMode === "battery" && !profileChecker.running) profileChecker.running = true;
        }
    }

    function setProfile(profileName) {
        batteryModule.activeProfile = profileName;
        Quickshell.execDetached(["powerprofilesctl", "set", profileName]);
    }

    // Header
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 24

        Text {
            text: "Battery & Power"
            font.pixelSize: 15
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            Layout.preferredWidth: 68
            Layout.preferredHeight: 22
            radius: 6
            color: batteryModule.isCharging ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.card_bg ?? "#1f2335")
            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: batteryModule.isCharging ? "󰂄" : "󰁹"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: batteryModule.isCharging ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.accent ?? "#7aa2f7")
                }
                Text {
                    text: batteryModule.batteryLevel + "%"
                    font.bold: true
                    font.pixelSize: 11
                    color: batteryModule.isCharging ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                }
            }
        }
    }

    // Health Card
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: 8
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
                    text: batteryModule.fullEnergyWh + " Wh / " + batteryModule.designEnergyWh + " Wh (" + batteryModule.healthPercentage + "%)"
                    font.pixelSize: 11
                    font.bold: true
                    color: batteryModule.healthPercentage > 75 ? (Theme.colors.accent ?? "#7aa2f7") : "#f44336"
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
                    color: batteryModule.healthPercentage > 75 ? (Theme.colors.accent ?? "#7aa2f7") : "#f44336"
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }
            }
        }
    }

    // Power Profiles Selector
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Power Profile"
            font.pixelSize: 11
            font.bold: true
            color: Theme.colors.text_secondary ?? "#565f89"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Power Saver
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 8
                property bool isSelected: batteryModule.activeProfile === "power-saver"
                color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (saverMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335"))
                border.width: isSelected ? 0 : 1
                border.color: Theme.colors.border ?? "#16161e"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰌪"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: parent.parent.isSelected ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                    }
                    Text {
                        text: "Power Saver"
                        font.bold: true
                        font.pixelSize: 10
                        color: parent.parent.isSelected ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                    }
                }
                MouseArea {
                    id: saverMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batteryModule.setProfile("power-saver")
                }
            }

            // Balanced
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 8
                property bool isSelected: batteryModule.activeProfile === "balanced"
                color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (balMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335"))
                border.width: isSelected ? 0 : 1
                border.color: Theme.colors.border ?? "#16161e"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰗑"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: parent.parent.isSelected ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                    }
                    Text {
                        text: "Balanced"
                        font.bold: true
                        font.pixelSize: 10
                        color: parent.parent.isSelected ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                    }
                }
                MouseArea {
                    id: balMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batteryModule.setProfile("balanced")
                }
            }

            // Performance
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 8
                property bool isSelected: batteryModule.activeProfile === "performance"
                color: isSelected ? (Theme.colors.accent ?? "#7aa2f7") : (perfMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : (Theme.colors.card_bg ?? "#1f2335"))
                border.width: isSelected ? 0 : 1
                border.color: Theme.colors.border ?? "#16161e"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰓅"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: parent.parent.isSelected ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                    }
                    Text {
                        text: "Performance"
                        font.bold: true
                        font.pixelSize: 10
                        color: parent.parent.isSelected ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                    }
                }
                MouseArea {
                    id: perfMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batteryModule.setProfile("performance")
                }
            }
        }
    }
}
