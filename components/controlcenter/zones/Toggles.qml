pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../../"

Rectangle {
    id: root

    property real em: 16
    property bool zoneActive: false
    property bool inZoneMode: false
    property int currentItemIndex: 0
    property int selectableCount: 2

    signal activated(int index)
    signal adjustValue(int delta)

    // Blue light filter command - configurable
    property string blueLightCmd: "hyprshade toggle blue-light-filter"

    implicitHeight: Math.round(em * 5)
    color: "transparent"
    border.width: root.zoneActive ? 2 : 0
    border.color: root.inZoneMode ? Colors.green : root.zoneActive ? Colors.blue : "transparent"

    // --- State ---
    property bool blueLightOn: false
    property bool idleInhibitOn: false

    // --- Blue light process ---
    Process {
        id: blueLightProc
        command: ["sh", "-c", root.blueLightCmd]
    }

    // --- Idle inhibit: hold a long-running process ---
    Process {
        id: idleProc
        command: ["wayland-idle-inhibitor"]
    }

    function toggle(index) {
        if (index === 0) {
            root.blueLightOn = !root.blueLightOn
            blueLightProc.running = true
        } else {
            root.idleInhibitOn = !root.idleInhibitOn
            if (root.idleInhibitOn) {
                idleProc.running = true
            } else {
                idleProc.running = false
            }
        }
    }

    // --- Toggle button component ---
    component ToggleBtn: Rectangle {
        id: btn
        property string icon: ""
        property string label: ""
        property bool on_: false
        property bool focused: false
        property color onColor: Colors.orange
        signal tapped()

        width: Math.round(root.em * 6)
        height: Math.round(root.em * 3.5)
        radius: Math.round(root.em * 0.8)

        color: on_
            ? Qt.rgba(onColor.r, onColor.g, onColor.b, 0.18)
            : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1)

        border.width: focused ? 2 : 1
        border.color: focused
            ? Colors.blue
            : on_ ? Qt.rgba(onColor.r, onColor.g, onColor.b, 0.5) : Colors.subtle

        Column {
            anchors.centerIn: parent
            spacing: Math.round(root.em * 0.25)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.icon
                color: btn.on_ ? btn.onColor : Colors.muted
                font { family: Colors.font; pixelSize: Math.round(root.em * 1.4) }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.label
                color: btn.on_ ? Colors.fg : Colors.muted
                font { family: Colors.font; pixelSize: Math.round(root.em * 0.7) }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: btn.tapped()
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Math.round(root.em * 1.5)

        ToggleBtn {
            icon: "󰛨"
            label: "Blue Light"
            on_: root.blueLightOn
            focused: root.inZoneMode && root.currentItemIndex === 0
            onColor: Colors.orange
            onTapped: root.toggle(0)
        }

        ToggleBtn {
            icon: "󰌵"
            label: "Idle Inhibit"
            on_: root.idleInhibitOn
            focused: root.inZoneMode && root.currentItemIndex === 1
            onColor: Colors.yellow
            onTapped: root.toggle(1)
        }
    }
}
