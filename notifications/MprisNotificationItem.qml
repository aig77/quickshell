import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: root

    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""

    signal dismissed()

    readonly property int cardWidth: 360

    width: cardWidth
    height: dismissing ? 0 : card.implicitHeight
    clip: true

    Behavior on height {
        NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
    }

    property bool dismissing: false

    x: 372
    Component.onCompleted: {
        slideIn.start()
        dismissTimer.start()
    }

    NumberAnimation {
        id: slideIn
        target: root; property: "x"
        from: 372; to: 0
        duration: 280; easing.type: Easing.OutCubic
    }

    Timer {
        id: dismissTimer
        interval: 5000
        repeat: false
        onTriggered: startDismiss()
    }

    function startDismiss() {
        if (dismissing) return
        dismissing = true
        dismissTimer.stop()
        fadeOut.start()
    }

    SequentialAnimation {
        id: fadeOut
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "opacity"
                to: 0; duration: 200; easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: root; property: "x"
                to: 372; duration: 200; easing.type: Easing.InCubic
            }
        }
        ScriptAction { script: root.dismissed() }
    }

    Rectangle {
        id: card
        width: root.cardWidth
        implicitHeight: content.implicitHeight + 20

        color: Colors.bg
        border.width: 2
        border.color: Colors.green
        radius: 16

        // Dismiss button
        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 10
            text: "✕"
            color: Colors.subtle
            font { family: Colors.font; pixelSize: 11 }
            z: 1
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: startDismiss()
            }
        }

        RowLayout {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: 10; anchors.bottomMargin: 10
            anchors.leftMargin: 10; anchors.rightMargin: 26
            spacing: 12

            // Album art
            Rectangle {
                width: 48
                height: 48
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: Colors.surface
                layer.enabled: true

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: 20 }
                    visible: albumArt.status !== Image.Ready
                }
            }

            // Track info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Colors.fg
                    font { family: Colors.font; pixelSize: 14; bold: true }
                    elide: Text.ElideRight
                    visible: root.title.length > 0
                }

                Text {
                    Layout.fillWidth: true
                    text: root.artist
                    color: Colors.fg
                    font { family: Colors.font; pixelSize: 12 }
                    elide: Text.ElideRight
                    visible: root.artist.length > 0
                }

                Text {
                    Layout.fillWidth: true
                    text: root.album
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: 11 }
                    elide: Text.ElideRight
                    visible: root.album.length > 0
                }
            }
        }
    }
}
