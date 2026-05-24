import QtQuick
import Quickshell.Io
import "../../"

Rectangle {
    id: root

    property real em: 16
    property bool zoneActive: false
    property bool inZoneMode: false
    property int currentItemIndex: 0
    property int selectableCount: 0

    signal activated(int index)
    signal adjustValue(int delta)

    implicitHeight: Math.round(em * 5)
    color: "transparent"
    border.width: root.zoneActive ? 2 : 0
    border.color: root.inZoneMode ? Colors.green : root.zoneActive ? Colors.blue : "transparent"

    // --- CPU ---
    property real cpuPercent: 0
    property real _prevIdle: 0
    property real _prevTotal: 0

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length < 5)
                    return;
                const vals = parts.slice(1).map(Number);
                const idle = vals[3] + (vals[4] ?? 0);
                const total = vals.reduce((a, b) => a + b, 0);
                const dIdle = idle - root._prevIdle;
                const dTotal = total - root._prevTotal;
                root.cpuPercent = dTotal > 0 ? Math.max(0, Math.min(1, (dTotal - dIdle) / dTotal)) : 0;
                root._prevIdle = idle;
                root._prevTotal = total;
            }
        }
    }

    // --- RAM ---
    property real ramPercent: 0

    Process {
        id: ramProc
        command: ["sh", "-c", "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length < 2)
                    return;
                const total = parseInt(lines[0].match(/\d+/)?.[0] ?? "0");
                const avail = parseInt(lines[1].match(/\d+/)?.[0] ?? "0");
                root.ramPercent = total > 0 ? (total - avail) / total : 0;
            }
        }
    }

    // --- GPU (AMD) ---
    property real gpuPercent: -1

    Process {
        id: gpuProc
        command: ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1 || echo -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                root.gpuPercent = isNaN(v) || v < 0 ? -1 : v / 100;
            }
        }
    }

    // --- Storage ---
    property real storagePercent: 0

    Process {
        id: storageProc
        command: ["sh", "-c", "df / --output=pcent 2>/dev/null | tail -1 | tr -d ' %'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                root.storagePercent = isNaN(v) ? 0 : v / 100;
            }
        }
    }

    // --- Polling timers ---
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProc.running = true;
            ramProc.running = true;
            gpuProc.running = true;
        }
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: storageProc.running = true
    }

    // --- Metric tile: icon + percentage + bar, no text label ---
    component MetricTile: Column {
        property string icon: ""
        property string label: ""
        property real value: 0
        property color barColor: Colors.blue
        property bool visible_: true

        visible: visible_
        spacing: Math.round(root.em * 0.3)
        width: Math.round(root.em * 4)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.icon
            color: parent.barColor
            font {
                family: Colors.font
                pixelSize: Math.round(root.em * 1.3)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.label
            color: parent.barColor
            font {
                family: Colors.font
                pixelSize: Math.round(root.em * 0.7)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(parent.value * 100) + "%"
            color: Colors.fg
            font {
                family: Colors.font
                pixelSize: Math.round(root.em * 0.85)
                bold: true
            }
        }

        Rectangle {
            width: parent.width
            height: Math.round(root.em * 0.4)
            color: Colors.muted

            Rectangle {
                width: Math.round(parent.width * parent.parent.value)
                height: parent.height
                color: parent.parent.barColor
                Behavior on width {
                    NumberAnimation {
                        duration: 400
                    }
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Math.round(root.em * 1.5)

        MetricTile {
            icon: ""
            label: ""
            value: root.cpuPercent
            barColor: Colors.blue
        }
        MetricTile {
            icon: ""
            label: "󰢮"
            value: Math.max(0, root.gpuPercent)
            barColor: Colors.cyan
            visible_: root.gpuPercent >= 0
        }
        MetricTile {
            icon: ""
            label: ""
            value: root.ramPercent
            barColor: Colors.purple
        }
        MetricTile {
            icon: ""
            label: "󰋊"
            value: root.storagePercent
            barColor: Colors.yellow
        }
    }
}
