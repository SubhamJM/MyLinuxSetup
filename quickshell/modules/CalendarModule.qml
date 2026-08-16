import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"

ColumnLayout {
    id: calModule
    spacing: 12
    Layout.fillWidth: true
    Layout.fillHeight: true

    property date viewDate: new Date()
    readonly property date today: new Date()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayNames: ["M", "T", "W", "T", "F", "S", "S"]

    function getDaysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function getFirstDayOffset(year, month) {
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

    // Top Header: Month, Year, and Minimal Controls
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        spacing: 8

        RowLayout {
            spacing: 6
            Text {
                text: calModule.monthNames[calModule.viewDate.getMonth()]
                font.pixelSize: 18
                font.bold: true
                color: Theme.colors.text_primary ?? "white"
            }
            Text {
                text: calModule.viewDate.getFullYear()
                font.pixelSize: 18
                font.bold: false
                color: Theme.colors.text_secondary ?? "#565f89"
            }
        }

        Item { Layout.fillWidth: true }

        // Minimal Action Pills
        RowLayout {
            spacing: 4

            Rectangle {
                width: 28; height: 28; radius: 14
                color: prevMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

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
                width: 28; height: 28; radius: 14
                color: todayMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "•"
                    font.pixelSize: 18
                    font.bold: true
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
                width: 28; height: 28; radius: 14
                color: nextMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

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
    }

    // Day of Week Header
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 16
        spacing: 8

        Repeater {
            model: calModule.dayNames
            Item {
                required property int index
                required property string modelData
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 11
                    font.bold: true
                    color: (index >= 5) ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                    opacity: (index >= 5) ? 0.7 : 0.4
                }
            }
        }
    }

    // Clean Minimal Calendar Grid
    GridLayout {
        id: calGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 7
        rows: 6
        columnSpacing: 8
        rowSpacing: 8

        readonly property int totalDays: calModule.getDaysInMonth(calModule.viewDate.getFullYear(), calModule.viewDate.getMonth())
        readonly property int startOffset: calModule.getFirstDayOffset(calModule.viewDate.getFullYear(), calModule.viewDate.getMonth())

        Repeater {
            model: 42
            delegate: Item {
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true

                property int dayNum: index - calGrid.startOffset + 1
                property int prevMonthDays: calModule.getDaysInMonth(
                    calModule.viewDate.getMonth() === 0 ? calModule.viewDate.getFullYear() - 1 : calModule.viewDate.getFullYear(),
                    calModule.viewDate.getMonth() === 0 ? 11 : calModule.viewDate.getMonth() - 1
                )
                property bool isValidDay: dayNum >= 1 && dayNum <= calGrid.totalDays
                property int displayDay: isValidDay ? dayNum : (dayNum <= 0 ? prevMonthDays + dayNum : dayNum - calGrid.totalDays)
                
                property bool isToday: isValidDay && 
                                       dayNum === calModule.today.getDate() && 
                                       calModule.viewDate.getMonth() === calModule.today.getMonth() && 
                                       calModule.viewDate.getFullYear() === calModule.today.getFullYear()

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    radius: 6
                    scale: cellMouse.containsMouse ? (parent.isValidDay ? 1.05 : 1.02) : 1.0

                    color: parent.isToday 
                        ? (Theme.colors.accent ?? "#7aa2f7") 
                        : (cellMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent")
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        text: parent.parent.displayDay
                        font.pixelSize: 13
                        font.bold: parent.parent.isToday
                        opacity: parent.parent.isValidDay ? (cellMouse.containsMouse ? 1.0 : 0.9) : (cellMouse.containsMouse ? 0.6 : 0.3)
                        color: parent.parent.isToday 
                            ? (Theme.colors.bg ?? "#16161e") 
                            : (cellMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "white"))
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!parent.parent.isValidDay) {
                                calModule.changeMonth(parent.parent.dayNum <= 0 ? -1 : 1);
                            }
                        }
                    }
                }
            }
        }
    }
}
