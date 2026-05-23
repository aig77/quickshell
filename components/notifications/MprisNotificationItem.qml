import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../"

Item {
    id: root

    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property string appId: ""

    signal dismissed()

    readonly property int cardWidth: 360

    property bool _shown: false

    width: cardWidth
    height: _shown ? card.implicitHeight : 0
    clip: true

    Behavior on height {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    x: 360

    function show() {
        _shown = true
        slideIn.start()
        dismissTimer.start()
    }

    NumberAnimation {
        id: slideIn
        target: root; property: "x"
        from: 360; to: 0
        duration: 280; easing.type: Easing.OutCubic
    }

    Timer {
        id: dismissTimer
        interval: 5000
        repeat: false
        onTriggered: startDismiss()
    }

    function startDismiss() {
        if (slideOut.running || !_shown) return
        dismissTimer.stop()
        slideOut.start()
    }

    SequentialAnimation {
        id: slideOut
        NumberAnimation {
            target: root; property: "x"
            to: 360; duration: 200; easing.type: Easing.InCubic
        }
        ScriptAction { script: root._shown = false }
        PauseAnimation { duration: 180 }
        ScriptAction { script: root.dismissed() }
    }

    Rectangle {
        id: card
        width: root.cardWidth
        anchors.bottom: parent.bottom
        implicitHeight: content.implicitHeight + 20

        color: Colors.bg
        border.width: 2
        border.color: Colors.green
        radius: 16

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    startDismiss()
                } else if (root.appId.length > 0) {
                    Hyprland.dispatch("focuswindow class:(?i)" + root.appId)
                }
            }
        }

        RowLayout {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: 10; anchors.bottomMargin: 10
            anchors.leftMargin: 14; anchors.rightMargin: 14
            spacing: 12

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
