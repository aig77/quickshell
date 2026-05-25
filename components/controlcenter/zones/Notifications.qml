pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../"
import "../"

Rectangle {
    id: root

    property real em: 16
    property bool zoneActive: false
    property bool inZoneMode: false
    property int currentItemIndex: 0
    // Last selectable index is the Clear button when notifications exist
    property int selectableCount: CCNotifModel.items.count > 0 ? CCNotifModel.items.count + 1 : 0
    readonly property bool clearFocused: root.inZoneMode && root.currentItemIndex === CCNotifModel.items.count
    property int hoveredIndex: -1

    function clearAll() {
        while (CCNotifModel.items.count > 0) {
            const uid = CCNotifModel.items.get(0).uid
            CCNotifModel.refs[uid]?.dismiss()
            CCNotifModel.removeNotif(uid)
        }
    }

    // Match Calendar height so both sides of row are equal
    implicitHeight: calHeight > 0 ? calHeight : Math.round(em * 12)
    property real calHeight: 0

    color: "transparent"
    border.width: root.zoneActive ? 2 : 0
    border.color: root.inZoneMode ? Colors.green : root.zoneActive ? Colors.blue : "transparent"

    Column {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Math.round(root.em * 0.6)
        }
        spacing: 0

        // Header: bell + count on left, clear on right
        Item {
            width: parent.width
            height: Math.round(root.em * 1.8)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                spacing: Math.round(root.em * 0.4)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰂚"
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.85) }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: CCNotifModel.items.count > 0 ? CCNotifModel.items.count + "" : ""
                    color: Colors.subtle
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.75) }
                    visible: CCNotifModel.items.count > 0
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                text: "Clear"
                color: root.clearFocused ? Colors.green : CCNotifModel.items.count > 0 ? Colors.muted : Colors.subtle
                font { family: Colors.font; pixelSize: Math.round(root.em * 0.75); bold: root.clearFocused }

                MouseArea {
                    anchors.fill: parent
                    enabled: CCNotifModel.items.count > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearAll()
                }
            }
        }

        // Separator
        Rectangle {
            width: parent.width
            height: 1
            color: Colors.subtle
            opacity: 0.5
        }

        Item { width: 1; height: Math.round(root.em * 0.4) }

        // Empty state
        Text {
            width: parent.width
            text: "No notifications"
            color: Colors.subtle
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }
            horizontalAlignment: Text.AlignHCenter
            topPadding: Math.round(root.em * 1.5)
            visible: CCNotifModel.items.count === 0
        }

        ListView {
            id: listView
            width: parent.width
            height: Math.min(
                contentHeight,
                root.implicitHeight
                    - Math.round(root.em * 1.8)
                    - 1
                    - Math.round(root.em * 0.4)
                    - Math.round(root.em * 0.6) * 2
            )
            model: CCNotifModel.items
            clip: true
            currentIndex: root.inZoneMode ? root.currentItemIndex : -1
            spacing: Math.round(root.em * 0.3)
            visible: CCNotifModel.items.count > 0

            delegate: Rectangle {
                id: notifRow
                required property var model
                required property int index

                readonly property bool isFocused: root.inZoneMode && notifRow.index === listView.currentIndex
                readonly property bool isHovered: root.hoveredIndex === notifRow.index

                width: listView.width
                height: Math.round(root.em * 2.4)
                radius: Math.round(root.em * 0.3)
                color: isFocused || isHovered
                    ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1)
                    : "transparent"
                border.width: isFocused ? 1 : 0
                border.color: Colors.green

                RowLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Math.round(root.em * 0.5)
                        rightMargin: Math.round(root.em * 0.5)
                    }
                    spacing: Math.round(root.em * 0.45)

                    // App icon / initial circle
                    Item {
                        Layout.preferredWidth: Math.round(root.em * 1.4)
                        Layout.preferredHeight: Math.round(root.em * 1.4)

                        Image {
                            id: iconImg
                            anchors.fill: parent
                            source: {
                                const ref = CCNotifModel.refs[notifRow.model.uid]
                                if (!ref) return ""
                                const img = ref.image
                                if (img && String(img).length > 0) return img
                                return ref.appIcon ?? ""
                            }
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Qt.rgba(Colors.blue.r, Colors.blue.g, Colors.blue.b, 0.15)
                            visible: iconImg.status !== Image.Ready

                            Text {
                                anchors.centerIn: parent
                                text: (notifRow.model.appName ?? "?").charAt(0).toUpperCase()
                                color: Colors.blue
                                font { family: Colors.font; pixelSize: Math.round(root.em * 0.7); bold: true }
                            }
                        }
                    }

                    // App name
                    Text {
                        Layout.fillWidth: true
                        text: notifRow.model.appName ?? ""
                        color: Colors.fg
                        font { family: Colors.font; pixelSize: Math.round(root.em * 0.75); bold: true }
                        elide: Text.ElideRight
                    }

                    // Timestamp
                    Text {
                        Layout.preferredWidth: Math.round(root.em * 2.4)
                        text: notifRow.model.time ?? ""
                        color: Colors.subtle
                        font { family: Colors.font; pixelSize: Math.round(root.em * 0.7) }
                        horizontalAlignment: Text.AlignRight
                    }

                    // X dismiss button
                    Text {
                        id: xBtn
                        Layout.preferredWidth: Math.round(root.em * 1.2)
                        text: "✕"
                        color: xArea.containsMouse ? Colors.fg : Colors.subtle
                        font { family: Colors.font; pixelSize: Math.round(root.em * 0.6) }
                        horizontalAlignment: Text.AlignHCenter

                        MouseArea {
                            id: xArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const uid = notifRow.model.uid
                                CCNotifModel.refs[uid]?.dismiss()
                                CCNotifModel.removeNotif(uid)
                            }
                        }
                    }
                }

                // Main row hover/click area (excludes X button area)
                MouseArea {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                        rightMargin: Math.round(root.em * 1.2) + Math.round(root.em * 0.5)
                    }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoveredIndex = notifRow.index
                    onExited: if (root.hoveredIndex === notifRow.index) root.hoveredIndex = -1
                    onClicked: {
                        Hyprland.dispatch("focuswindow class:(?i)" + (notifRow.model.appName ?? ""))
                    }
                }
            }
        }
    }
}
