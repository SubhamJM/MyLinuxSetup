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
                font.pixelSize: 15
                font.bold: true
                color: Theme.colors.text_primary ?? "white"
            }
            Text {
                text: calModule.viewDate.getFullYear()
                font.pixelSize: 15
                font.bold: false
                color: Theme.colors.text_secondary ?? "#565f89"
            }
        }

        Item { Layout.fillWidth: true }

        // Minimal Action Pills
        RowLayout {
            spacing: 4

            Rectangle {
                width: 24; height: 24; radius: 12
                color: prevMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅁"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
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
                width: 24; height: 24; radius: 12
                color: todayMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "•"
                    font.pixelSize: 16
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
                width: 24; height: 24; radius: 12
                color: nextMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅂"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
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
        spacing: 2

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
        columnSpacing: 2
        rowSpacing: 2

        readonly property int totalDays: calModule.getDaysInMonth(calModule.viewDate.getFullYear(), calModule.viewDate.getMonth())
        readonly property int startOffset: calModule.getFirstDayOffset(calModule.viewDate.getFullYear(), calModule.viewDate.getMonth())

        Repeater {
            model: 42
            delegate: Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                property int dayNum: index - calGrid.startOffset + 1
                property bool isValidDay: dayNum >= 1 && dayNum <= calGrid.totalDays
                property bool isToday: isValidDay && 
                                       dayNum === calModule.today.getDate() && 
                                       calModule.viewDate.getMonth() === calModule.today.getMonth() && 
                                       calModule.viewDate.getFullYear() === calModule.today.getFullYear()

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.92
                    height: width
                    radius: width / 2

                    color: parent.isToday 
                        ? (Theme.colors.accent ?? "#7aa2f7") 
                        : (cellMouse.containsMouse && parent.isValidDay ? (Theme.colors.hover_bg ?? "#24283b") : "transparent")
                    
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        visible: parent.parent.isValidDay
                        text: parent.parent.dayNum > 0 ? parent.parent.dayNum : ""
                        font.pixelSize: 12
                        font.bold: parent.parent.isToday
                        color: parent.parent.isToday 
                            ? (Theme.colors.bg ?? "#16161e") 
                            : (cellMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "white"))
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: parent.parent.isValidDay
                        cursorShape: parent.parent.isValidDay ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
        }
    }
}
