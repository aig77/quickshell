pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../../"

Rectangle {
    id: root

    property real em: 16
    property bool zoneActive: false
    property bool inZoneMode: false
    property int currentItemIndex: 0
    // 0=volume, 1=brightness, 2=blue light, 3=idle inhibit
    property int selectableCount: 4

    signal activated(int index)
    signal adjustValue(int delta)

    implicitHeight: Math.round(em * 6)
    HoverHandler { id: zoneHover }

    color: root.inZoneMode ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08)
         : (root.zoneActive || zoneHover.hovered) ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.04)
         : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    // --- Brightness ---
    property real brightnessRatio: 0
    property bool brightnessAvailable: false
    property int _brightVal: 0
    property int _brightMax: 1

    Process {
        id: brightGetProc
        command: ["brightnessctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (!isNaN(v) && v >= 0) {
                    root._brightVal = v;
                    root.brightnessRatio = root._brightMax > 0 ? root._brightVal / root._brightMax : 0;
                    root.brightnessAvailable = true;
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root.brightnessAvailable = false;
        }
    }

    Process {
        id: brightMaxProc
        command: ["brightnessctl", "max"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (!isNaN(v) && v > 0) {
                    root._brightMax = v;
                    brightGetProc.running = true;
                } else {
                    root.brightnessAvailable = false;
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root.brightnessAvailable = false;
        }
    }

    Process {
        id: brightSetProc
        property string _pct: "50"
        command: ["brightnessctl", "set", brightSetProc._pct + "%"]
    }

    function setBrightness(ratio) {
        if (!root.brightnessAvailable)
            return;
        const pct = Math.round(Math.max(0, Math.min(1, ratio)) * 100);
        root.brightnessRatio = Math.max(0, Math.min(1, ratio));
        brightSetProc._pct = pct.toString();
        brightSetProc.running = true;
    }

    // --- Volume ---
    property real volumeRatio: 0
    property bool volumeMuted: false

    Process {
        id: volGetProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                const v = parseFloat(parts[1] ?? "0");
                root.volumeRatio = isNaN(v) ? 0 : Math.min(v, 1.5) / 1.5;
                root.volumeMuted = text.includes("[MUTED]");
            }
        }
    }

    Process {
        id: volSetProc
        property string _pct: "50%"
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volSetProc._pct]
    }

    Process {
        id: muteToggleProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onExited: volGetProc.running = true
    }

    function setVolume(ratio) {
        const pct = Math.round(Math.max(0, Math.min(1, ratio)) * 100);
        root.volumeRatio = Math.max(0, Math.min(1, ratio));
        volSetProc._pct = pct + "%";
        volSetProc.running = true;
    }

    // --- Toggles ---
    property bool blueLightOn: false
    property bool idleInhibitOn: false

    Process {
        id: blueLightProc
        property bool _on: false
        command: _on
            ? ["systemctl", "--user", "start", "wlsunset"]
            : ["systemctl", "--user", "stop", "wlsunset"]
    }

    Process {
        id: idleProc
        command: ["systemd-inhibit", "--what=idle", "--mode=block", "--why=Manual", "sleep", "infinity"]
    }

    Component.onCompleted: {
        brightMaxProc.running = true;
        volGetProc.running = true;
    }

    // Keyboard adjust from ControlCenter (indices 0=volume, 1=brightness)
    function keyAdjust(index, delta) {
        const step = 0.05;
        if (index === 0)
            setVolume(root.volumeRatio + delta * step);
        else if (index === 1)
            setBrightness(root.brightnessRatio + delta * step);
    }

    // Activate toggle (indices 2=blue light, 3=idle inhibit)
    function toggle(index) {
        if (index === 2) {
            root.blueLightOn = !root.blueLightOn;
            blueLightProc._on = root.blueLightOn;
            blueLightProc.running = true;
        } else if (index === 3) {
            root.idleInhibitOn = !root.idleInhibitOn;
            idleProc.running = root.idleInhibitOn;
        }
    }

    // --- Slider row component ---
    component SliderRow: Item {
        id: sliderRow
        property string iconOff: ""
        property string iconOn: ""
        property real value: 0
        property bool focused: false
        property bool enabled_: true
        property bool toggled: false
        signal dragged(real newValue)
        signal iconTapped

        height: Math.round(root.em * 2.4)

        HoverHandler { id: sliderHover }

        Row {
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
            }
            spacing: Math.round(root.em * 0.7)

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(root.em * 1.4)
                height: Math.round(root.em * 1.4)

                Text {
                    anchors.centerIn: parent
                    text: sliderRow.toggled ? sliderRow.iconOn : sliderRow.iconOff
                    color: !sliderRow.enabled_ ? Colors.subtle : (sliderRow.focused || sliderHover.hovered) ? Colors.blue : Colors.muted
                    font {
                        family: Colors.font
                        pixelSize: Math.round(root.em * 1.1)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: sliderRow.iconTapped()
                    enabled: sliderRow.enabled_
                }
            }

            Item {
                id: trackArea
                anchors.verticalCenter: parent.verticalCenter
                width: sliderRow.width - Math.round(root.em * 1.4) - Math.round(root.em * 0.7) * 2 - Math.round(root.em * 1.8)
                height: Math.round(root.em * 0.5)

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: sliderRow.enabled_ ? Colors.muted : Colors.subtle
                    opacity: sliderRow.enabled_ ? 1.0 : 0.4
                }

                Rectangle {
                    width: Math.round(parent.width * sliderRow.value)
                    height: parent.height
                    radius: height / 2
                    color: sliderRow.enabled_ ? Colors.blue : Colors.subtle
                    opacity: sliderRow.enabled_ ? 1.0 : 0.4
                    Behavior on width {
                        NumberAnimation {
                            duration: 80
                        }
                    }
                }

                Rectangle {
                    x: Math.round(trackArea.width * sliderRow.value) - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(root.em * 0.9)
                    height: width
                    radius: width / 2
                    color: (sliderRow.focused || sliderHover.hovered) ? Colors.blue : Colors.fg
                    visible: sliderRow.enabled_
                    Behavior on x {
                        NumberAnimation {
                            duration: 80
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Math.round(root.em * 0.5)
                    enabled: sliderRow.enabled_
                    onPositionChanged: mouse => {
                        const margin = Math.round(root.em * 0.5);
                        const ratio = Math.max(0, Math.min(1, (mouseX - margin) / trackArea.width));
                        sliderRow.dragged(ratio);
                    }
                    onClicked: mouse => {
                        const margin = Math.round(root.em * 0.5);
                        const ratio = Math.max(0, Math.min(1, (mouseX - margin) / trackArea.width));
                        sliderRow.dragged(ratio);
                    }
                }
            }

            Text {
                id: pctLabel
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(sliderRow.value * 100) + "%"
                color: sliderRow.enabled_ ? ((sliderRow.focused || sliderHover.hovered) ? Colors.fg : Colors.muted) : Colors.subtle
                opacity: sliderRow.enabled_ ? 1.0 : 0.4
                font {
                    family: Colors.font
                    pixelSize: Math.round(root.em * 0.8)
                }
                width: Math.round(root.em * 1.8)
            }
        }
    }

    // --- Toggle circle button component ---
    component CircleToggle: Rectangle {
        id: circleBtn
        property string iconOff: ""
        property string iconOn: ""
        property bool on_: false
        property bool focused: false
        property color offColor: Colors.muted
        property color onColor: Colors.orange
        signal tapped

        readonly property color _activeColor: on_ ? onColor : offColor

        readonly property real btnSize: Math.round(root.em * 2.0)
        width: btnSize
        height: btnSize
        radius: btnSize / 2

        color: focused || btnHover.hovered
            ? (on_ ? Qt.rgba(onColor.r, onColor.g, onColor.b, 0.3)  : Qt.rgba(offColor.r, offColor.g, offColor.b, 0.15))
            : (on_ ? Qt.rgba(onColor.r, onColor.g, onColor.b, 0.2)  : Qt.rgba(offColor.r, offColor.g, offColor.b, 0.08))

        border.width: focused || btnHover.hovered ? 2 : 1
        border.color: focused || btnHover.hovered ? _activeColor : Qt.rgba(_activeColor.r, _activeColor.g, _activeColor.b, 0.5)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            anchors.centerIn: parent
            text: circleBtn.on_ ? circleBtn.iconOn : circleBtn.iconOff
            color: circleBtn.on_ ? circleBtn.onColor : Qt.rgba(circleBtn.offColor.r, circleBtn.offColor.g, circleBtn.offColor.b, 0.7)
            font {
                family: Colors.font
                pixelSize: Math.round(root.em * 1.0)
            }
        }

        HoverHandler { id: btnHover }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: circleBtn.tapped()
        }
    }

    // --- Layout: sliders on left, toggle circles stacked on right ---
    Column {
        id: toggleCol
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: Math.round(root.em * 1.2)
        }
        spacing: Math.round(root.em * 0.55)

        CircleToggle {
            iconOff: ""
            iconOn: ""
            on_: root.blueLightOn
            offColor: Colors.orange
            onColor: Colors.purple
            focused: root.inZoneMode && root.currentItemIndex === 2
            onTapped: root.toggle(2)
        }

        CircleToggle {
            iconOff: "󰈉"
            iconOn: "󰈈"
            on_: root.idleInhibitOn
            offColor: Colors.blue
            onColor: Colors.yellow
            focused: root.inZoneMode && root.currentItemIndex === 3
            onTapped: root.toggle(3)
        }
    }

    Column {
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            right: toggleCol.left
            leftMargin: Math.round(root.em * 1.2)
            rightMargin: Math.round(root.em * 1.8)
        }

        SliderRow {
            width: parent.width
            iconOff: "󰖁"
            iconOn: "󰕾"
            toggled: !root.volumeMuted
            value: root.volumeRatio
            focused: root.inZoneMode && root.currentItemIndex === 0
            enabled_: true
            onDragged: v => root.setVolume(v)
            onIconTapped: muteToggleProc.running = true
        }

        SliderRow {
            width: parent.width
            iconOff: "󰃞"
            iconOn: "󰃠"
            toggled: false
            value: root.brightnessRatio
            focused: root.inZoneMode && root.currentItemIndex === 1
            enabled_: root.brightnessAvailable
            onDragged: v => root.setBrightness(v)
            onIconTapped: {}
        }
    }
}
