pragma ComponentBehavior: Bound

import QtQuick
import "../../"

Rectangle {
    id: root

    property real em: 16
    property bool zoneActive: false
    property bool inZoneMode: false
    property bool confirmMode: false
    property int currentItemIndex: 0
    property int selectableCount: 4

    signal activated(int index)
    signal adjustValue(int delta)
    signal confirmed(var cmd)

    function actionCmd(index) {
        const cmds = [
            ["systemctl", "poweroff"],
            ["systemctl", "reboot"],
            ["systemctl", "suspend"],
            ["qs", "ipc", "call", "lockscreen", "lock"]
        ]
        return cmds[index] ?? []
    }

    implicitHeight: Math.round(em * 4.5)
        + (root.confirmMode ? confirmBar.implicitHeight : 0)

    color: "transparent"
    border.width: root.zoneActive ? 2 : 0
    border.color: root.inZoneMode ? Colors.green : root.zoneActive ? Colors.blue : "transparent"

    readonly property var _actions: [
        { icon: "⏻",  label: "Power",   color: Colors.red    },
        { icon: "󰜉",  label: "Restart", color: Colors.blue   },
        { icon: "󰒲",  label: "Sleep",   color: Colors.purple },
        { icon: "󰌾",  label: "Lock",    color: Colors.green  }
    ]

    Column {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        // Button row
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(root.em * 1.2)
            topPadding: Math.round(root.em * 0.7)
            bottomPadding: Math.round(root.em * 0.7)

            Repeater {
                model: root._actions
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    required property int index

                    readonly property bool isFocused: root.inZoneMode
                        && root.currentItemIndex === index
                    readonly property bool isConfirming: root.confirmMode
                        && root.currentItemIndex === index

                    readonly property real btnSize: Math.round(root.em * 2.8)
                    width: btnSize
                    height: btnSize
                    radius: btnSize / 2

                    color: isConfirming
                        ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.25)
                        : isFocused || hovered
                            ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.2)
                            : Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.1)

                    border.width: isFocused || isConfirming ? 2 : 1
                    border.color: isFocused
                        ? Colors.green
                        : isConfirming
                            ? modelData.color
                            : Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.45)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    property bool hovered: false

                    Text {
                        anchors.centerIn: parent
                        text: btn.modelData.icon
                        color: btn.modelData.color
                        font { family: Colors.font; pixelSize: Math.round(root.em * 1.2) }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: btn.hovered = true
                        onExited: btn.hovered = false
                        onClicked: {
                            // Mouse: show inline confirm for this button
                            root.currentItemIndex = btn.index
                            root.confirmMode = true
                            root.activated(btn.index)
                        }
                    }
                }
            }
        }

        // Confirm bar - fades in when confirmMode is active
        Rectangle {
            id: confirmBar
            width: parent.width
            implicitHeight: root.confirmMode ? Math.round(root.em * 2.2) : 0
            clip: true
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.6)
            visible: root.confirmMode

            Behavior on implicitHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Row {
                anchors.centerIn: parent
                spacing: Math.round(root.em * 1.5)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Enter to confirm"
                    color: Colors.fg
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.confirmed(root.actionCmd(root.currentItemIndex))
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "|"
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Esc to cancel"
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.confirmMode = false
                        }
                    }
                }
            }
        }
    }
}
