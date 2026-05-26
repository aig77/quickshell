pragma ComponentBehavior: Bound

import QtQuick
import "../../"

Rectangle {
    id: root

    property real em: 16
    property bool zoneActive: false
    property int focusedIndex: -1  // 0-3 = which button is focused; -1 = none
    property bool confirmMode: false

    signal activated(int index)
    signal adjustValue(int delta)

    function actionCmd(index) {
        const cmds = [["shutdown", "now"], ["reboot"], ["systemctl", "suspend"], ["hyprlock"]];
        return cmds[index] ?? [];
    }

    implicitHeight: Math.round(em * 4.5)

    HoverHandler {
        id: zoneHover
    }

    color: root.inZoneMode ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08) : (root.zoneActive || zoneHover.hovered) ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.04) : "transparent"
    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    readonly property var _actions: [
        {
            icon: "⏻",
            label: "Power",
            color: Colors.red
        },
        {
            icon: "",
            label: "Restart",
            color: Colors.blue
        },
        {
            icon: "󰒲",
            label: "Sleep",
            color: Colors.purple
        },
        {
            icon: "󰌾",
            label: "Lock",
            color: Colors.green
        }
    ]

    Item {
        anchors.fill: parent

        Row {
            anchors.centerIn: parent
            spacing: Math.round(root.em * 1.2)

            Repeater {
                model: root._actions
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    required property int index

                    readonly property bool isFocused: root.focusedIndex === index
                    readonly property bool isConfirming: root.confirmMode && root.focusedIndex === index

                    readonly property real btnSize: Math.round(root.em * 2.8)
                    width: btnSize
                    height: btnSize
                    radius: btnSize / 2

                    color: isConfirming ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.25) : isFocused || hovered ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.2) : Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.1)

                    border.width: isFocused || isConfirming ? 2 : 1
                    border.color: isFocused || isConfirming ? modelData.color : Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.45)

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    property bool hovered: false

                    Text {
                        anchors.centerIn: parent
                        text: btn.modelData.icon
                        color: btn.modelData.color
                        font {
                            family: Colors.font
                            pixelSize: Math.round(root.em * 1.2)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: btn.hovered = true
                        onExited: btn.hovered = false
                        onClicked: root.activated(btn.index)
                    }
                }
            }
        }
    }
}
