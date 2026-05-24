pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"

Rectangle {
    id: root

    property real em: 16
    property bool zoneActive: false
    property bool inZoneMode: false
    property int currentItemIndex: 0
    property int selectableCount: 3  // prev, play/pause, next

    signal activated(int index)
    signal adjustValue(int delta)

    function activate(index) {
        const player = Mpris.players.values[0] ?? null
        if (!player) return
        if (index === 0) player.previous()
        else if (index === 1) player.togglePlaying()
        else if (index === 2) player.next()
    }

    readonly property var _player: Mpris.players.values.length > 0
        ? Mpris.players.values[0] : null
    readonly property bool _hasPlayer: _player !== null

    implicitHeight: Math.round(em * 9)
    color: "transparent"
    border.width: root.zoneActive ? 2 : 0
    border.color: root.inZoneMode ? Colors.green : root.zoneActive ? Colors.blue : "transparent"

    // --- Cava ---
    property var cavaBars: []
    readonly property int cavaBarCount: 20

    Process {
        id: cavaProc
        running: root._hasPlayer
        command: [
            "bash", "-c",
            "cava -p <(printf '[general]\\nbars = " + root.cavaBarCount + "\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 100\\n')"
        ]
        stdout: StdioCollector {
            onStreamFinished: {}
        }
    }

    // Cava stdout line parsing via stdinout - use a simpler approach: read lines as they come
    // Since StdioCollector buffers all output, use a Process with periodic reads instead
    // For now render decorative bars, cava integration TBD via separate Process with line-by-line reading
    Timer {
        interval: 100
        running: root._hasPlayer
        repeat: true
        onTriggered: {
            // Animate decorative bars when playing
            if (root._player?.playbackState === MprisPlaybackState.Playing) {
                const bars = []
                for (let i = 0; i < root.cavaBarCount; i++) {
                    bars.push(Math.random())
                }
                root.cavaBars = bars
            } else {
                root.cavaBars = Array(root.cavaBarCount).fill(0.05)
            }
        }
    }

    // Gradient color per bar index
    function barColor(idx) {
        const t = idx / (root.cavaBarCount - 1)
        if (t < 0.33) {
            return Qt.rgba(
                Colors.green.r + (Colors.yellow.r - Colors.green.r) * (t / 0.33),
                Colors.green.g + (Colors.yellow.g - Colors.green.g) * (t / 0.33),
                Colors.green.b + (Colors.yellow.b - Colors.green.b) * (t / 0.33),
                1
            )
        } else if (t < 0.66) {
            const s = (t - 0.33) / 0.33
            return Qt.rgba(
                Colors.yellow.r + (Colors.red.r - Colors.yellow.r) * s,
                Colors.yellow.g + (Colors.red.g - Colors.yellow.g) * s,
                Colors.yellow.b + (Colors.red.b - Colors.yellow.b) * s,
                1
            )
        } else {
            const s = (t - 0.66) / 0.34
            return Qt.rgba(
                Colors.red.r + (Colors.purple.r - Colors.red.r) * s,
                Colors.red.g + (Colors.purple.g - Colors.red.g) * s,
                Colors.red.b + (Colors.purple.b - Colors.red.b) * s,
                1
            )
        }
    }

    // No player state
    Text {
        anchors.centerIn: parent
        text: "No media playing"
        color: Colors.muted
        font { family: Colors.font; pixelSize: Math.round(root.em * 0.85) }
        visible: !root._hasPlayer
    }

    Column {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Math.round(root.em * 0.8)
        }
        spacing: Math.round(root.em * 0.5)
        visible: root._hasPlayer

        // Track info row
        Row {
            width: parent.width
            spacing: Math.round(root.em * 0.8)

            // Album art
            Rectangle {
                width: Math.round(root.em * 3)
                height: width
                radius: Math.round(root.em * 0.4)
                color: Colors.surface

                Image {
                    anchors.fill: parent
                    anchors.margins: 0
                    source: root._player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source.toString().length > 0
                    layer.enabled: true
                    layer.effect: null
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(root.em * 1.2) }
                    visible: (root._player?.trackArtUrl ?? "").toString().length === 0
                }
            }

            // Title + artist
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Math.round(root.em * 3) - Math.round(root.em * 0.8)
                spacing: Math.round(root.em * 0.15)

                Text {
                    width: parent.width
                    text: root._player?.trackTitle ?? ""
                    color: Colors.fg
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.9); bold: true }
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root._player?.trackArtist ?? ""
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }
                    elide: Text.ElideRight
                }
            }
        }

        // Controls row
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(root.em * 1.5)

            Repeater {
                model: [
                    { icon: "󰒮", idx: 0 },
                    { icon: root._player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊", idx: 1 },
                    { icon: "󰒯", idx: 2 }
                ]
                delegate: Rectangle {
                    id: ctrlBtn
                    required property var modelData

                    readonly property bool isFocused: root.inZoneMode
                        && root.currentItemIndex === modelData.idx
                    property bool hovered: false

                    width: Math.round(root.em * 2.2)
                    height: width
                    radius: width / 2
                    color: isFocused || hovered
                        ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1)
                        : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.4)

                    Text {
                        anchors.centerIn: parent
                        text: ctrlBtn.modelData.icon
                        color: ctrlBtn.isFocused ? Colors.green : Colors.fg
                        font { family: Colors.font; pixelSize: Math.round(root.em * 1.1) }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: ctrlBtn.hovered = true
                        onExited: ctrlBtn.hovered = false
                        onClicked: root.activate(ctrlBtn.modelData.idx)
                    }
                }
            }
        }

        // Cava visualizer - only visible when a player is active
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(root.em * 0.15)
            visible: root._hasPlayer

            Repeater {
                model: root.cavaBarCount
                delegate: Rectangle {
                    required property int index
                    readonly property real barH: root.cavaBars[index] ?? 0.05

                    width: Math.round(root.em * 0.55)
                    height: Math.round(root.em * 2)
                    color: "transparent"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: Math.max(Math.round(root.em * 0.15), Math.round(parent.height * barH))
                        radius: width / 2
                        color: root.barColor(index)
                        Behavior on height { NumberAnimation { duration: 80 } }
                    }
                }
            }
        }
    }
}
