import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import "../"

Item {
    id: root

    property var notif: null
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
    }

    function startAutoTimer() {
        if (notif && notif.urgency !== NotificationUrgency.Critical) {
            dismissTimer.interval = notif.expireTimeout > 0 ? notif.expireTimeout : 5000
            dismissTimer.start()
        }
    }

    NumberAnimation {
        id: slideIn
        target: root; property: "x"
        from: 360; to: 0
        duration: 280; easing.type: Easing.OutCubic
    }

    Timer {
        id: dismissTimer
        repeat: false
        onTriggered: startDismiss()
    }

    Connections {
        target: notif
        function onClosed(reason) { startDismiss() }
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
        border.color: notif?.urgency === NotificationUrgency.Critical ? Colors.red
                    : notif?.urgency === NotificationUrgency.Low      ? Colors.subtle
                    :                                                    Colors.blue
        radius: 16

        Image {
            id: iconProbe
            source: (notif?.image?.length ?? 0) > 0 ? notif.image : (notif?.appIcon ?? "")
            visible: false
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    notif.dismiss()
                    startDismiss()
                } else {
                    Hyprland.dispatch("focuswindow class:(?i)" + (notif?.appName ?? ""))
                }
            }
        }

        RowLayout {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: 10; anchors.bottomMargin: 10
            anchors.leftMargin: 14; anchors.rightMargin: 14
            spacing: 10

            Rectangle {
                visible: iconProbe.status === Image.Ready
                width: 40
                height: 40
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: Colors.surface
                layer.enabled: true

                Image {
                    anchors.fill: parent
                    source: (notif?.image?.length ?? 0) > 0 ? notif.image : (notif?.appIcon ?? "")
                    fillMode: Image.PreserveAspectCrop
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: notif?.summary ?? ""
                    color: Colors.fg
                    font { family: Colors.font; pixelSize: 14; bold: true }
                    wrapMode: Text.WordWrap
                    visible: (notif?.summary?.length ?? 0) > 0
                }

                Text {
                    Layout.fillWidth: true
                    text: notif?.body ?? ""
                    color: Colors.fg
                    font { family: Colors.font; pixelSize: 12 }
                    wrapMode: Text.WordWrap
                    visible: (notif?.body?.length ?? 0) > 0
                    textFormat: Text.StyledText
                }

                Text {
                    Layout.fillWidth: true
                    text: notif?.appName ?? ""
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: 11 }
                    elide: Text.ElideRight
                    visible: iconProbe.status !== Image.Ready && (notif?.appName?.length ?? 0) > 0
                }
            }
        }
    }
}
