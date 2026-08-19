import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"

ColumnLayout {
    id: notifModule
    spacing: 10
    Layout.fillWidth: true
    Layout.fillHeight: true

    readonly property int calculatedCount: globalNotifModel.count

    // Header: Title, Count Badge, Clear All
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        spacing: 8

        RowLayout {
            spacing: 6
            Text {
                text: "󰂚"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: Theme.colors.accent ?? "#7aa2f7"
            }
            Text {
                text: "Notifications"
                font.family: "Inter"
                font.pixelSize: 14
                font.bold: true
                color: Theme.colors.text_primary ?? "white"
            }
            Rectangle {
                visible: globalNotifModel.count > 0
                width: countText.implicitWidth + 10
                height: 18
                radius: 9
                color: Qt.rgba((Theme.colors.accent ?? "#7aa2f7").r, (Theme.colors.accent ?? "#7aa2f7").g, (Theme.colors.accent ?? "#7aa2f7").b, 0.2)

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: globalNotifModel.count
                    font.family: "Inter"
                    font.pixelSize: 10
                    font.bold: true
                    color: Theme.colors.accent ?? "#7aa2f7"
                }
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: globalNotifModel.count > 0
            Layout.preferredWidth: 68
            Layout.preferredHeight: 24
            radius: 6
            color: clearMouse.containsMouse ? (Theme.colors.error ?? "#f44336") : (Theme.colors.card_bg ?? "#1f2335")
            border.width: 1
            border.color: Theme.colors.border ?? "#16161e"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "Clear All"
                font.family: "Inter"
                font.pixelSize: 11
                font.bold: true
                color: clearMouse.containsMouse ? "white" : (Theme.colors.text_secondary ?? "#565f89")
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    for (var i = 0; i < globalNotifModel.count; i++) {
                        var item = globalNotifModel.get(i);
                        if (item && item.notifObj) item.notifObj.dismiss();
                    }
                    globalNotifModel.clear();
                }
            }
        }
    }

    // Notification Cards List
    ListView {
        id: notifList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: globalNotifModel

        boundsBehavior: Flickable.DragAndOvershootBounds
        maximumFlickVelocity: 3500
        flickDeceleration: 2200

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4
            contentItem: Rectangle {
                radius: 2
                color: Theme.colors.text_secondary ?? "#565f89"
                opacity: 0.4
            }
        }

        Item {
            anchors.fill: parent
            visible: globalNotifModel.count === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰂜"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 32
                    color: Theme.colors.text_secondary ?? "#565f89"
                    opacity: 0.5
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No notifications"
                    font.family: "Inter"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.colors.text_secondary ?? "#565f89"
                }
            }
        }

        delegate: Rectangle {
            width: ListView.view.width
            implicitHeight: cardContent.implicitHeight + 16
            radius: 10
            color: Theme.colors.card_bg ?? "#1f2335"
            border.width: 1
            border.color: Theme.colors.border ?? "#16161e"
            clip: true

            ColumnLayout {
                id: cardContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Image {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        source: appIcon ? ("image://icon/" + appIcon) : ""
                        visible: appIcon !== ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Text {
                        text: appName ? appName : "System"
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.colors.accent ?? "#7aa2f7"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: dismissMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 10
                            color: dismissMouse.containsMouse ? (Theme.colors.error ?? "#f44336") : (Theme.colors.text_secondary ?? "#565f89")
                        }

                        MouseArea {
                            id: dismissMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (notifObj) notifObj.dismiss();
                                globalNotifModel.remove(index);
                            }
                        }
                    }
                }

                Text {
                    text: summary
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.bold: true
                    color: Theme.colors.text_primary ?? "white"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: summary !== ""
                }

                Text {
                    text: body
                    font.family: "Inter"
                    font.pixelSize: 11
                    color: Theme.colors.text_secondary ?? "#565f89"
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: body !== ""
                }
            }
        }
    }
}
