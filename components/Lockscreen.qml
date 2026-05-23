import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import "./"

Scope {
    id: root

    property bool _locked: false
    property string _password: ""
    property bool _checking: false
    property bool _failed: false
    property bool _capsLock: false
    property string _username: "arturo"

    // ── IPC: quickshell ipc call lockscreen lock ───────────────────────────
    IpcHandler {
        target: "lockscreen"
        function lock(): void { root._locked = true }
    }

    // ── Fetch username ─────────────────────────────────────────────────────
    Process {
        running: true
        command: ["sh", "-c", "echo -n $USER"]
        stdout: StdioCollector {
            onStreamFinished: {
                var u = text.trim()
                if (u.length > 0) root._username = u
            }
        }
    }

    // ── Caps lock polling (only while locked) ──────────────────────────────
    Component {
        id: capsComp
        Process {
            id: _capsProcInner
            running: true
            command: ["sh", "-c",
                "cat /sys/class/leds/input*::capslock/brightness 2>/dev/null | head -1 || echo 0"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root._capsLock = text.trim() === "1"
                    Qt.callLater(_capsProcInner.destroy)
                }
            }
        }
    }
    Timer {
        interval: 500
        running: root._locked
        repeat: true
        onTriggered: capsComp.createObject(root)
    }

    // ── Auth ───────────────────────────────────────────────────────────────
    PamContext {
        id: pam
        user: root._username
        config: "login"

        onPamMessage: {
            if (responseRequired)
                pam.respond(root._password)
        }

        onCompleted: (result) => {
            if (result === PamResult.Success) {
                root._locked = false
            } else {
                root._failed = true
                root._password = ""
                failResetTimer.restart()
            }
            root._checking = false
        }

        onError: (err) => {
            root._failed = true
            root._password = ""
            failResetTimer.restart()
            root._checking = false
        }
    }

    Timer {
        id: failResetTimer
        interval: 1500
        onTriggered: root._failed = false
    }

    function submitPassword() {
        if (_checking || _password.length === 0) return
        _checking = true
        _failed = false
        pam.start()
    }

    // ── Session lock ───────────────────────────────────────────────────────
    // locked: false = idle (no Wayland lock held)
    // locked: true  = session locked, surfaces shown on all screens
    WlSessionLock {
        id: lock
        locked: root._locked

        LockSurface {
            locked: root._locked
            password: root._password
            checking: root._checking
            failed: root._failed
            capsLock: root._capsLock
            username: root._username
            onPasswordUpdated: (p) => { root._password = p }
            onSubmitRequested: root.submitPassword()
            onClearRequested: { root._password = "" }
        }
    }
}
