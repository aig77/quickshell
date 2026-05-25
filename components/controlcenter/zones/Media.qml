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

    implicitHeight: Math.round(em * 9.8)
    HoverHandler { id: zoneHover }

    color: root.inZoneMode ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08)
         : (root.zoneActive || zoneHover.hovered) ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.04)
         : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

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
        bottomPadding: Math.round(root.em * 0.8)
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
                        color: ctrlBtn.isFocused ? Colors.blue : Colors.fg
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
                delegate: Item {
                    required property int index
                    readonly property real barH: root.cavaBars[index] ?? 0.05
                    readonly property real maxH: Math.round(root.em * 2)
                    readonly property real fillH: Math.max(Math.round(root.em * 0.15), Math.round(maxH * barH))

                    width: Math.round(root.em * 0.55)
                    height: maxH

                    // Clip Item grows from the bottom to reveal the vertical gradient
                    Item {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: fillH
                        clip: true

                        Behavior on height { NumberAnimation { duration: 80 } }

                        // Full-height gradient anchored to this clip Item's bottom
                        // so low bars show the green (bottom) end, tall bars reveal purple (top)
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.parent.maxH
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0;  color: Colors.purple }
                                GradientStop { position: 0.35; color: Colors.red    }
                                GradientStop { position: 0.65; color: Colors.yellow }
                                GradientStop { position: 1.0;  color: Colors.green  }
                            }
                        }
                    }
                }
            }
        }
    }
}
