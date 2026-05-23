import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "./"

WlSessionLockSurface {
    id: root

    // Props bound from Lockscreen
    property bool isPrimary: false
    property bool locked: false
    property string password: ""
    property bool checking: false
    property bool failed: false
    property bool capsLock: false
    property string username: ""

    signal passwordUpdated(string p)
    signal submitRequested()
    signal clearRequested()

    // ── Intro animation ────────────────────────────────────────────────────
    property real _lockProgress: 0

    onLockedChanged: {
        if (locked) {
            _lockProgress = 0
            lockInAnim.restart()
        }
    }

    NumberAnimation {
        id: lockInAnim
        target: root
        property: "_lockProgress"
        from: 0; to: 1
        duration: 500
        easing.type: Easing.OutCubic
    }

    // ── Clock timer ────────────────────────────────────────────────────────
    property var _now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root._now = new Date()
    }

    // Reset TextInput when Lockscreen externally clears the password
    onPasswordChanged: {
        if (password.length === 0 && pwInput.text.length > 0)
            pwInput.text = ""
    }

    // ── Hidden TextInput — captures keyboard on the focused surface ─────────
    TextInput {
        id: pwInput
        visible: false
        focus: true
        echoMode: TextInput.NoEcho
        onTextChanged: root.passwordUpdated(text)
        Keys.onReturnPressed: root.submitRequested()
        Keys.onEscapePressed: { text = ""; root.clearRequested() }
    }

    // ── All content fades in together ──────────────────────────────────────
    Item {
        width: root.width
        height: root.height
        opacity: root._lockProgress

        // ── Background: blurred wallpaper ──────────────────────────────────
        Item {
            width: root.width
            height: root.height
            clip: true

            Image {
                id: wallpaper
                width: root.width + 128
                height: root.height + 128
                x: -64
                y: -64
                source: "file:///home/arturo/.cache/bebop/current-wallpaper"
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            MultiEffect {
                source: wallpaper
                x: -64
                y: -64
                width: root.width + 128
                height: root.height + 128
                blurEnabled: true
                blur: 0.6
                blurMax: 64
            }
        }

        // ── Dark overlay ───────────────────────────────────────────────────
        Rectangle {
            width: root.width
            height: root.height
            color: Colors.bg
            opacity: 0.45
        }

        // ── Clock ──────────────────────────────────────────────────────────
        Text {
            x: (root.width - width) / 2
            y: root.height / 2 - 380 - height / 2
            text: Qt.formatTime(root._now, "HH:mm")
            color: Colors.fg
            font { family: Colors.font; pixelSize: 120 }
            style: Text.Raised
            styleColor: "#99000000"
        }

        // ── Date ───────────────────────────────────────────────────────────
        Text {
            x: (root.width - width) / 2
            y: root.height / 2 - 250 - height / 2
            text: Qt.formatDate(root._now, "dddd, MMMM d")
            color: Colors.fg
            font { family: Colors.font; pixelSize: 28 }
            style: Text.Raised
            styleColor: "#99000000"
        }

        // ── Password field ─────────────────────────────────────────────────
        Rectangle {
            id: inputField
            x: (root.width - width) / 2
            y: root.height / 2 + 20 - height / 2
            width: 200
            height: 50
            radius: 25
            color: Colors.bg

            opacity: root.password.length === 0 ? 0.65 : 1.0
            Behavior on opacity { NumberAnimation { duration: 600 } }

            border.width: 3
            border.color: root.failed   ? Colors.red
                        : root.checking ? Colors.cyan
                        :                 Colors.fg
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Row {
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        required property int index
                        width: 8
                        height: 8
                        radius: 4
                        color: index < root.password.length ? Colors.fg : "transparent"
                        border.width: 1
                        border.color: index < root.password.length ? "transparent" : Colors.muted
                        opacity: root.password.length === 0 ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        Behavior on color   { ColorAnimation  { duration: 100 } }
                    }
                }
            }
        }

        // ── Auth failure message ───────────────────────────────────────────
        Text {
            visible: root.failed
            x: (root.width - width) / 2
            y: root.height / 2 + 55 - height / 2
            text: "Incorrect password"
            color: Colors.red
            font { family: Colors.font; pixelSize: 13; italic: true }
        }

        // ── Caps Lock indicator ────────────────────────────────────────────
        Text {
            visible: root.capsLock
            x: (root.width - width) / 2
            y: root.height / 2 + 80 - height / 2
            text: "Caps Lock ON"
            color: Colors.red
            font { family: Colors.font; pixelSize: 14 }
        }

        // ── Username ───────────────────────────────────────────────────────
        Text {
            x: (root.width - width) / 2
            y: root.height / 2 + 180 - height / 2
            text: "\uf007  " + root.username
            color: Colors.fg
            font { family: Colors.font; pixelSize: 18 }
            style: Text.Raised
            styleColor: "#99000000"
        }
    }
}
