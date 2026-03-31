import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../"

Scope {
    id: root

    property var currentPlayer: null
    property bool visible: false

    // Watch all players for track changes
    Repeater {
        model: Mpris.players
        delegate: Item {
            required property var modelData

            Connections {
                target: modelData
                function onTrackChanged() {
                    if (modelData.isPlaying && modelData.trackTitle.length > 0) {
                        root.currentPlayer = modelData
                        root.visible = true
                        hideTimer.restart()
                        slideIn.restart()
                    }
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 5000
        repeat: false
        onTriggered: root.visible = false
    }

    PanelWindow {
        id: win
        anchors.top: true
        anchors.right: true
        implicitWidth: 384
        implicitHeight: root.visible ? 66 + card.height + 8 : 0
        color: "transparent"
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

        Item {
            id: popupItem
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 66
            anchors.rightMargin: 22
            width: 360
            height: card.height
            opacity: root.visible ? 1 : 0
            x: root.visible ? 0 : 372

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.InQuad }
            }

            NumberAnimation {
                id: slideIn
                target: popupItem
                property: "x"
                from: 372; to: 0
                duration: 280; easing.type: Easing.OutCubic
            }

            Rectangle {
                id: card
                width: parent.width
                height: row.implicitHeight + 20
                color: Colors.bg
                border.width: 2
                border.color: Colors.subtle
                radius: 16

                RowLayout {
                    id: row
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 10
                    }
                    spacing: 12

                    // Album art
                    Rectangle {
                        width: 56
                        height: 56
                        radius: 8
                        color: Colors.surface
                        clip: true

                        Image {
                            id: albumArt
                            anchors.fill: parent
                            source: root.currentPlayer?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }

                        // Fallback icon when no art
                        Text {
                            anchors.centerIn: parent
                            text: "♪"
                            color: Colors.muted
                            font { family: Colors.font; pixelSize: 24 }
                            visible: albumArt.status !== Image.Ready
                        }
                    }

                    // Track info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.currentPlayer?.trackTitle ?? ""
                            color: Colors.fg
                            font { family: Colors.font; pixelSize: 14; bold: true }
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.currentPlayer?.trackArtist ?? ""
                            color: Colors.fg
                            font { family: Colors.font; pixelSize: 12 }
                            elide: Text.ElideRight
                            visible: (root.currentPlayer?.trackArtist ?? "").length > 0
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.currentPlayer?.trackAlbum ?? ""
                            color: Colors.subtle
                            font { family: Colors.font; pixelSize: 11 }
                            elide: Text.ElideRight
                            visible: (root.currentPlayer?.trackAlbum ?? "").length > 0
                        }
                    }
                }
            }
        }
    }
}
