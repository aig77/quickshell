import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../"

Item {
    id: root

    property var notif: null
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
        from: 372; to: 0
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
        border.color: notif?.urgency === NotificationUrgency.Critical ? Colors.red
                    : notif?.urgency === NotificationUrgency.Low      ? Colors.subtle
                    :                                                    Colors.blue
        radius: 16

        // Hidden image just to probe load status
        Image {
            id: iconProbe
            source: (notif?.image?.length ?? 0) > 0 ? notif.image : (notif?.appIcon ?? "")
            visible: false
        }

        // Dismiss button — top right corner
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
                onClicked: {
                    notif.dismiss()
                    startDismiss()
                }
            }
        }

        RowLayout {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: 10; anchors.bottomMargin: 10
            anchors.leftMargin: 14; anchors.rightMargin: 26
            spacing: 10

            // Icon — only shown when loaded successfully
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

            // Text column
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

                // App name fallback — only shown when no icon
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
