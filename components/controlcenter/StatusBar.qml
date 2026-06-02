import QtQuick
import Quickshell.Io
import "../"

Rectangle {
    id: root

    property string zoneIcon: ""
    property string zoneName: ""
    property string itemName: ""
    property real em: 16

    property int _nixDays: -1

    readonly property color _nixColor: _nixDays < 0
        ? Colors.subtle
        : _nixDays < 14
            ? Colors.green
            : _nixDays < 30
                ? Colors.yellow
                : Colors.red

    Process {
        id: nixAgeProc
        command: ["sh", "-c",
            "python3 -c \"import json,time,os; d=json.load(open(os.path.expanduser('~/.config/bebop/flake.lock'))); print(int((time.time()-d['nodes']['nixpkgs']['locked']['lastModified'])/86400))\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim())
                if (!isNaN(v) && v >= 0)
                    root._nixDays = v
            }
        }
    }

    Timer {
        interval: 3600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: nixAgeProc.running = true
    }

    height: Math.round(em * 2.4)
    color: "transparent"

    // Title (left)
    Row {
        anchors.left: parent.left
        anchors.leftMargin: Math.round(root.em * 0.8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.em * 0.6)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.zoneIcon
            color: Colors.blue
            font { family: Colors.font; pixelSize: Math.round(root.em * 1.1) }
            visible: root.zoneIcon.length > 0
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.zoneName
            color: Colors.blue
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.9); bold: true }
            visible: root.zoneName.length > 0
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "|"
            color: Colors.muted
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }
            visible: root.itemName.length > 0
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.itemName
            color: Colors.muted
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }
            visible: root.itemName.length > 0
        }
    }

    // Nix staleness (right)
    Row {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.em * 0.8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.em * 0.35)

        Image {
            anchors.verticalCenter: parent.verticalCenter
            source: "/run/current-system/sw/share/icons/hicolor/scalable/apps/nix-snowflake.svg"
            width: Math.round(root.em * 1.0)
            height: Math.round(root.em * 1.0)
            smooth: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root._nixDays < 0 ? "..." : root._nixDays + "d"
            color: root._nixColor
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.8); bold: true }
        }
    }
}
