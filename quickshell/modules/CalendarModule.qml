import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"

ColumnLayout {
    id: calModule
    spacing: 8
    Layout.fillWidth: true
    Layout.fillHeight: true

    property date viewDate: new Date()
    readonly property date today: new Date()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayNames: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    function getDaysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function getFirstDayOffset(year, month) {
        // Shift Sunday (0) to end of week index (6)
        var day = new Date(year, month, 1).getDay();
        return (day === 0) ? 6 : day - 1;
    }

    function changeMonth(delta) {
        var newMonth = viewDate.getMonth() + delta;
        var newYear = viewDate.getFullYear();
        if (newMonth < 0) {
            newMonth = 11;
            newYear--;
        } else if (newMonth > 11) {
            newMonth = 0;
            newYear++;
        }
        viewDate = new Date(newYear, newMonth, 1);
    }

    // Header (Month, Year, Navigation)
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        spacing: 6

        Text {
            text: calModule.monthNames[calModule.viewDate.getMonth()] + " " + calModule.viewDate.getFullYear()
            font.pixelSize: 15
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            width: 26; height: 26; radius: 6
            color: prevMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
            border.width: prevMouse.containsMouse ? 1 : 0
            border.color: Theme.colors.border_hover ?? "#7aa2f7"

            Text {
                anchors.centerIn: parent
                text: "󰅁"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: prevMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
            }
            MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: calModule.changeMonth(-1)
            }
        }

        Rectangle {
            width: 26; height: 26; radius: 6
            color: todayMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
            border.width: todayMouse.containsMouse ? 1 : 0
            border.color: Theme.colors.border_hover ?? "#7aa2f7"

            Text {
                anchors.centerIn: parent
                text: "󰃭"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: todayMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
            }
            MouseArea {
                id: todayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: calModule.viewDate = new Date()
            }
        }

        Rectangle {
            width: 26; height: 26; radius: 6
            color: nextMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
            border.width: nextMouse.containsMouse ? 1 : 0
            border.color: Theme.colors.border_hover ?? "#7aa2f7"

            Text {
                anchors.centerIn: parent
                text: "󰅂"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: nextMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
            }
            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: calModule.changeMonth(1)
            }
        }
    }

    // Days of Week Header
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 18
        spacing: 4

        Repeater {
            model: calModule.dayNames
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.colors.text_secondary ?? "#565f89"
                }
            }
        }
    }

    // Month Grid (7 Columns x 6 Rows)
    GridLayout {
        id: calGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 7
        rows: 6
        columnSpacing: 4
        rowSpacing: 4

        readonly property int totalDays: calModule.getDaysInMonth(calModule.viewDate.getFullYear(), calModule.viewDate.getMonth())
        readonly property int startOffset: calModule.getFirstDayOffset(calModule.viewDate.getFullYear(), calModule.viewDate.getMonth())

        Repeater {
            model: 42
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6

                property int dayNum: index - calGrid.startOffset + 1
                property bool isValidDay: dayNum >= 1 && dayNum <= calGrid.totalDays
                property bool isToday: isValidDay && 
                                       dayNum === calModule.today.getDate() && 
                                       calModule.viewDate.getMonth() === calModule.today.getMonth() && 
                                       calModule.viewDate.getFullYear() === calModule.today.getFullYear()

                color: isToday ? (Theme.colors.accent ?? "#7aa2f7") : (cellMouse.containsMouse && isValidDay ? (Theme.colors.hover_bg ?? "#24283b") : "transparent")
                border.width: (cellMouse.containsMouse && !isToday && isValidDay) ? 1 : 0
                border.color: Theme.colors.border_hover ?? "#7aa2f7"

                Text {
                    anchors.centerIn: parent
                    visible: parent.isValidDay
                    text: parent.dayNum > 0 ? parent.dayNum : ""
                    font.pixelSize: 12
                    font.bold: parent.isToday
                    color: parent.isToday ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: parent.isValidDay
                    cursorShape: parent.isValidDay ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }
        }
    }
}
