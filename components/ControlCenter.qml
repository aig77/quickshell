pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "./"
import "./controlcenter/"
import "./controlcenter/zones/"

Scope {
    id: root

    // --- Navigation state ---
    property bool open: false
    property string navMode: "view"  // "view" | "panel" | "zone" | "confirm"
    property int focusedZone: 0        // 0-10
    property int zoneItemIndex: 0
    property int row0Column: 1         // 0=clock, 1=weather (sticky; clock is not keyboard-navigable so always start at weather)
    property int row1Column: 0         // 0=notifications, 1=calendar (sticky)
    property int powerColumn: 0        // 0-3 = shutdown/restart/sleep/lock (sticky)
    property var pendingPowerAction: []
    property int _confirmFocus: 0  // 0=Confirm, 1=Cancel

    // Notification whose body is shown in the detail popup (keyboard focus or mouse hover)
    readonly property var _popupNotif: {
        if (!root.open)
            return null;
        if (root.navMode === "zone" && root.focusedZone === 3) {
            if (root.zoneItemIndex >= CCNotifModel.items.count)
                return null;
            return CCNotifModel.items.get(root.zoneItemIndex) ?? null;
        }
        const hi = z3.hoveredIndex;
        if (hi >= 0)
            return CCNotifModel.items.get(hi) ?? null;
        return null;
    }

    readonly property var zoneMeta: [
        {
            icon: "󰅐",
            name: "Clock"
        },
        {
            icon: "󰖕",
            name: "Weather"
        },
        {
            icon: "󰃵",
            name: "Calendar"
        },
        {
            icon: "󰂚",
            name: "Notifications"
        },
        {
            icon: "󰁝",
            name: "Controls"
        },
        {
            icon: "󰻠",
            name: "Metrics"
        },
        {
            icon: "󰝚",
            name: "Media"
        },
        {
            icon: "⏻",
            name: "Shutdown"
        },
        {
            icon: "",
            name: "Restart"
        },
        {
            icon: "󰒲",
            name: "Sleep"
        },
        {
            icon: "󰌾",
            name: "Lock"
        },
    ]

    // Row order matches visual layout: Clock/Weather | Controls | Notifications/Calendar | Media | Metrics | Power(x4)
    readonly property var _rows: [[0, 1], [4], [3, 2], [6], [5], [7, 8, 9, 10]]

    function nextZone(current, dir) {
        let ri = _rows.findIndex(r => r.includes(current));
        ri = (ri + dir + _rows.length) % _rows.length;
        const row = _rows[ri];
        if (row.length === 1)
            return row[0];
        if (ri === 0)
            return row[root.row0Column];
        if (ri === 5)
            return row[root.powerColumn];
        return row[root.row1Column];
    }

    function currentItemName(zone, index) {
        switch (zone) {
        case 2:
            {
                if (index === 0)
                    return "Prev Month";
                if (index === z2._daysInMonth + 1)
                    return "Next Month";
                return "Day " + index;
            }
        case 3:
            {
                if (index === CCNotifModel.items.count)
                    return "Clear All";
                const notif = CCNotifModel.items.get(index);
                if (!notif)
                    return "";
                const s = notif.appName;
                return s.length > 22 ? s.substring(0, 19) + "..." : s;
            }
        case 1:
            return "Refresh";
        case 4:
            return (["Volume", "Brightness", "Blue Light", "Idle Inhibit"])[index] ?? "";
        case 6:
            return (["Previous", "Play/Pause", "Next"])[index] ?? "";
        default:
            return "";
        }
    }

    onOpenChanged: {
        CCState.open = open;
        if (open) {
            navMode = "view";
            focusedZone = 0;
            zoneItemIndex = 0;
            powerColumn = 0;
            pendingPowerAction = [];
        }
    }

    // --- Notification detail popup: appears to the right of the panel ---
    PanelWindow {
        id: popupWin
        anchors.right: true
        anchors.top: true
        visible: root.open && root._popupNotif !== null
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:controlcenter:notifdetail"

        readonly property real em: screen ? Math.round(screen.height * 0.018) : 16
        readonly property real _panelW: screen ? Math.min(Math.round(screen.width * 0.4), 600) : 480

        // Height of everything below the notification zone (media + metrics + power + 3 separators)
        readonly property real _belowNotifH: Math.round(win.em * 9.2) + Math.round(win.em * 5) + Math.round(win.em * 4.5) + 3
        readonly property real _notifZoneH: z2.implicitHeight
        readonly property real _notifZoneTopY: screen ? Math.round((screen.height - panel.implicitHeight) / 2) + panel.implicitHeight - _belowNotifH - _notifZoneH : 200

        implicitWidth: Math.round(em * 16)
        implicitHeight: popupCard.implicitHeight

        WlrLayershell.margins.right: screen ? Math.round(screen.width / 2 + _panelW / 2) + Math.round(em * 0.5) : 400
        WlrLayershell.margins.top: Math.round(_notifZoneTopY + _notifZoneH / 2 - implicitHeight / 2)

        Rectangle {
            id: popupCard
            width: parent.width
            implicitHeight: popupCol.implicitHeight + Math.round(popupWin.em * 1.2)
            color: Colors.bg
            border.width: 1
            border.color: Colors.subtle

            Column {
                id: popupCol
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: Math.round(popupWin.em * 0.6)
                    leftMargin: Math.round(popupWin.em * 0.8)
                    rightMargin: Math.round(popupWin.em * 0.8)
                }
                spacing: Math.round(popupWin.em * 0.3)

                Text {
                    width: parent.width
                    text: root._popupNotif?.summary ?? ""
                    color: Colors.fg
                    font {
                        family: Colors.font
                        pixelSize: Math.round(popupWin.em * 0.85)
                        bold: true
                    }
                    wrapMode: Text.WordWrap
                    visible: (root._popupNotif?.summary ?? "").length > 0
                }

                Text {
                    width: parent.width
                    text: root._popupNotif?.body ?? ""
                    color: Colors.muted
                    font {
                        family: Colors.font
                        pixelSize: Math.round(popupWin.em * 0.8)
                    }
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    visible: (root._popupNotif?.body ?? "").length > 0
                }
            }
        }
    }

    // --- Power confirm popup: appears to the right of the panel ---
    PanelWindow {
        id: powerConfirmWin
        anchors.left: true
        anchors.top: true
        visible: root.open && root.navMode === "confirm"
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        // Exclusive in confirm mode: gets keyboard focus so key nav works,
        // and pointer events route here naturally (no exclusive grab on win).
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:controlcenter:powerconfirm"

        readonly property real em: screen ? Math.round(screen.height * 0.018) : 16
        readonly property real _panelW: screen ? Math.min(Math.round(screen.width * 0.4), 600) : 480
        readonly property var _actionColors: [Colors.red, Colors.blue, Colors.purple, Colors.green]
        readonly property real _zoneH: Math.round(win.em * 4.5)

        readonly property real _powerZoneTopY: screen ? Math.round((screen.height - panel.implicitHeight) / 2) + panel.implicitHeight - _zoneH : 300

        implicitWidth: Math.round(em * 8)
        implicitHeight: pcCol.implicitHeight

        WlrLayershell.margins.left: screen ? Math.round(screen.width / 2 + _panelW / 2) + Math.round(em * 0.5) : 400
        WlrLayershell.margins.top: Math.round(_powerZoneTopY + _zoneH / 2 - implicitHeight / 2)

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_J:
                case Qt.Key_K:
                    root._confirmFocus = root._confirmFocus === 0 ? 1 : 0;
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (root._confirmFocus === 0)
                        keyArea.executePendingAction();
                    else {
                        root.navMode = "zone";
                        root.pendingPowerAction = [];
                    }
                    event.accepted = true;
                    break;
                case Qt.Key_Escape:
                    root.navMode = "zone";
                    root.pendingPowerAction = [];
                    event.accepted = true;
                    break;
                }
            }

            Rectangle {
                id: pcCard
                anchors.fill: parent
                color: Colors.bg
                border.width: 1
                border.color: Colors.subtle

                Column {
                    id: pcCol
                    width: parent.width

                    // Confirm
                    Rectangle {
                        id: confirmBtn
                        width: parent.width
                        height: Math.round(powerConfirmWin.em * 2.2)
                        property bool hovered: false

                        readonly property color _ac: powerConfirmWin._actionColors[root.zoneItemIndex] ?? Colors.fg
                        readonly property bool _active: root._confirmFocus === 0 || hovered

                        color: _active ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Confirm"
                            color: confirmBtn._ac
                            font {
                                family: Colors.font
                                pixelSize: Math.round(powerConfirmWin.em * 0.85)
                                bold: confirmBtn._active
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: confirmBtn.hovered = true
                            onExited: confirmBtn.hovered = false
                            onClicked: keyArea.executePendingAction()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Colors.subtle
                    }

                    // Cancel
                    Rectangle {
                        id: cancelBtn
                        width: parent.width
                        height: Math.round(powerConfirmWin.em * 2.2)
                        property bool hovered: false

                        readonly property bool _active: root._confirmFocus === 1 || hovered

                        color: _active ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: cancelBtn._active ? Colors.fg : Colors.muted
                            font {
                                family: Colors.font
                                pixelSize: Math.round(powerConfirmWin.em * 0.85)
                                bold: cancelBtn._active
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: cancelBtn.hovered = true
                            onExited: cancelBtn.hovered = false
                            onClicked: {
                                root.navMode = "zone";
                                root.pendingPowerAction = [];
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Scrim window: WlrLayer.Top so panel (Overlay) is always above it ---
    PanelWindow {
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
        visible: root.open || scrimRect.opacity > 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:controlcenter:scrim"

        Rectangle {
            id: scrimRect
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            opacity: 0.0

            NumberAnimation {
                id: scrimOpenAnim
                target: scrimRect
                property: "opacity"
                to: 1.0
                duration: 180
            }
            NumberAnimation {
                id: scrimCloseAnim
                target: scrimRect
                property: "opacity"
                to: 0.0
                duration: 180
            }
            Connections {
                target: root
                function onOpenChanged() {
                    if (root.open) {
                        scrimCloseAnim.stop();
                        scrimRect.opacity = 0.0;
                        scrimOpenAnim.start();
                    } else {
                        scrimOpenAnim.stop();
                        if (scrimRect.opacity > 0)
                            scrimCloseAnim.start();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.open
                onClicked: root.open = false
            }
        }
    }

    // --- Panel window: WlrLayer.Overlay, always above scrim ---
    PanelWindow {
        id: win
        anchors.top: true
        color: "transparent"
        visible: root.open || panel.opacity > 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:controlcenter"

        readonly property real em: screen ? Math.round(screen.height * 0.018) : 16
        readonly property real panelW: screen ? Math.min(Math.round(screen.width * 0.4), 600) : 480

        implicitWidth: panelW
        implicitHeight: screen ? screen.height : 1080

        WlrLayershell.margins.top: screen && panel.implicitHeight > 0 ? Math.round((screen.height - panel.height) / 2) : 60

        HyprlandFocusGrab {
            id: grab
            windows: [win, popupWin, powerConfirmWin]
            active: root.open
            onCleared: if (!active)
                root.open = false
        }

        Item {
            id: keyArea
            anchors.fill: parent
            focus: root.open

            Keys.onPressed: event => {
                if (root.navMode === "view") {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.open = false;
                        event.accepted = true;
                        break;
                    case Qt.Key_J:
                    case Qt.Key_K:
                    case Qt.Key_H:
                    case Qt.Key_L:
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.navMode = "panel";
                        root.focusedZone = 0;
                        root.row0Column = 0;
                        event.accepted = true;
                        break;
                    }
                } else if (root.navMode === "panel") {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.open = false;
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (root.focusedZone === 1) {
                            z1.refresh();
                        } else if (root.focusedZone >= 7 && root.focusedZone <= 10) {
                            root.pendingPowerAction = z7.actionCmd(root.focusedZone - 7);
                            root._confirmFocus = 0;
                            root.navMode = "confirm";
                        } else if (zoneSelectableCount(root.focusedZone) > 0) {
                            root.navMode = "zone";
                            root.zoneItemIndex = 0;
                        }
                        event.accepted = true;
                        break;
                    case Qt.Key_J:
                        root.focusedZone = root.nextZone(root.focusedZone, 1);
                        if (root.focusedZone === 2 || root.focusedZone === 3)
                            root.row1Column = root.focusedZone === 3 ? 0 : 1;
                        if (root.focusedZone === 0 || root.focusedZone === 1)
                            root.row0Column = root.focusedZone;
                        if (root.focusedZone >= 7 && root.focusedZone <= 10)
                            root.powerColumn = root.focusedZone - 7;
                        event.accepted = true;
                        break;
                    case Qt.Key_K:
                        root.focusedZone = root.nextZone(root.focusedZone, -1);
                        if (root.focusedZone === 2 || root.focusedZone === 3)
                            root.row1Column = root.focusedZone === 3 ? 0 : 1;
                        if (root.focusedZone === 0 || root.focusedZone === 1)
                            root.row0Column = root.focusedZone;
                        if (root.focusedZone >= 7 && root.focusedZone <= 10)
                            root.powerColumn = root.focusedZone - 7;
                        event.accepted = true;
                        break;
                    case Qt.Key_H:
                        if (root.focusedZone >= 7 && root.focusedZone <= 10) {
                            root.powerColumn = Math.max(0, root.focusedZone - 7 - 1);
                            root.focusedZone = 7 + root.powerColumn;
                        } else if (root.focusedZone === 2 || root.focusedZone === 3) {
                            root.focusedZone = 3;  // notifications is left
                            root.row1Column = 0;
                        } else if (root.focusedZone === 0 || root.focusedZone === 1) {
                            root.focusedZone = 0;  // clock is left
                            root.row0Column = 0;
                        }
                        event.accepted = true;
                        break;
                    case Qt.Key_L:
                        if (root.focusedZone >= 7 && root.focusedZone <= 10) {
                            root.powerColumn = Math.min(3, root.focusedZone - 7 + 1);
                            root.focusedZone = 7 + root.powerColumn;
                        } else if (root.focusedZone === 2 || root.focusedZone === 3) {
                            root.focusedZone = 2;  // calendar is right
                            root.row1Column = 1;
                        } else if (root.focusedZone === 0 || root.focusedZone === 1) {
                            root.focusedZone = 1;  // weather is right
                            root.row0Column = 1;
                        }
                        event.accepted = true;
                        break;
                    }
                } else if (root.navMode === "zone") {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.navMode = "panel";
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        zoneActivate(root.focusedZone, root.zoneItemIndex);
                        event.accepted = true;
                        break;
                    case Qt.Key_J:
                        zoneMoveDir(root.focusedZone, 0, 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_K:
                        zoneMoveDir(root.focusedZone, 0, -1);
                        event.accepted = true;
                        break;
                    case Qt.Key_L:
                        zoneMoveDir(root.focusedZone, 1, 0);
                        event.accepted = true;
                        break;
                    case Qt.Key_H:
                        zoneMoveDir(root.focusedZone, -1, 0);
                        event.accepted = true;
                        break;
                    case Qt.Key_Plus:
                    case Qt.Key_Equal:
                        zoneAdjust(root.focusedZone, root.zoneItemIndex, 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Minus:
                        zoneAdjust(root.focusedZone, root.zoneItemIndex, -1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Backspace:
                        if (root.focusedZone === 3 && root.zoneItemIndex < CCNotifModel.items.count) {
                            const uid = CCNotifModel.items.get(root.zoneItemIndex)?.uid;
                            if (uid !== undefined) {
                                CCNotifModel.refs[uid]?.dismiss();
                                CCNotifModel.removeNotif(uid);
                                root.zoneItemIndex = Math.min(root.zoneItemIndex, z3.selectableCount - 1);
                            }
                        }
                        event.accepted = true;
                        break;
                    }
                } else if (root.navMode === "confirm") {
                    switch (event.key) {
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (root._confirmFocus === 0) {
                            executePendingAction();
                        } else {
                            root.navMode = "zone";
                            root.pendingPowerAction = [];
                        }
                        event.accepted = true;
                        break;
                    case Qt.Key_J:
                    case Qt.Key_K:
                        root._confirmFocus = root._confirmFocus === 0 ? 1 : 0;
                        event.accepted = true;
                        break;
                    case Qt.Key_Escape:
                        root.navMode = "zone";
                        root.pendingPowerAction = [];
                        event.accepted = true;
                        break;
                    }
                }
            }

            function zoneMoveDir(zone, dx, dy) {
                if (zone === 2) {
                    // Calendar: header row has [prev (col 0)] and [next (col 1)].
                    // j from header enters the day grid. k from header does nothing (top).
                    // From days: k above week 1 returns to prev button; h/l = ±1 day; j/k = ±7 days.
                    const N = z2._daysInMonth;
                    const cur = root.zoneItemIndex;
                    if (cur === 0) {
                        // Prev button: l → next, j → first day, h/k → nothing
                        if (dx > 0)
                            root.zoneItemIndex = N + 1;
                        else if (dy > 0)
                            root.zoneItemIndex = 1;
                    } else if (cur === N + 1) {
                        // Next button: h → prev, j → first day, l/k → nothing
                        if (dx < 0)
                            root.zoneItemIndex = 0;
                        else if (dy > 0)
                            root.zoneItemIndex = 1;
                    } else {
                        // On a day: h/l = ±1 day, j/k = ±7 days (one week)
                        const step = dx !== 0 ? dx : dy * 7;
                        const next = cur + step;
                        if (next < 1)
                            root.zoneItemIndex = 0;
                        else if (next > N)
                            root.zoneItemIndex = N + 1;
                        else
                            root.zoneItemIndex = next;
                    }
                } else if (zone === 4) {
                    // Controls: 2x2 grid
                    // col 0: volume (0), brightness (1)
                    // col 1: blue light (2), idle inhibit (3)
                    const col = root.zoneItemIndex < 2 ? 0 : 1;
                    const row = root.zoneItemIndex % 2;
                    const newCol = Math.max(0, Math.min(1, col + dx));
                    const newRow = Math.max(0, Math.min(1, row + dy));
                    root.zoneItemIndex = newCol * 2 + newRow;
                } else {
                    // Linear for all other zones (j/l = forward, k/h = back)
                    const dir = dx !== 0 ? dx : dy;
                    const count = zoneSelectableCount(zone);
                    if (count > 0)
                        root.zoneItemIndex = (root.zoneItemIndex + dir + count) % count;
                }
            }

            function zoneActivate(zone, index) {
                if (zone === 2) {
                    if (index === 0) {
                        z2.adjustMonth(-1);
                        root.zoneItemIndex = 0;
                    } else if (index === z2._daysInMonth + 1) {
                        z2.adjustMonth(1);
                        root.zoneItemIndex = z2._daysInMonth + 1;
                    }
                } else if (zone === 3) {
                    if (index === CCNotifModel.items.count) {
                        z3.clearAll();
                    } else {
                        const appName = CCNotifModel.items.get(index)?.appName ?? "";
                        if (appName.length > 0)
                            Hyprland.dispatch("focuswindow class:(?i)" + appName);
                        root.open = false;
                    }
                } else if (zone === 4) {
                    z4.toggle(index);
                } else if (zone === 6) {
                    z6.activate(index);
                } else if (zone >= 7 && zone <= 10) {
                    root.pendingPowerAction = z7.actionCmd(zone - 7);
                    root._confirmFocus = 0;
                    root.navMode = "confirm";
                }
            }

            function zoneAdjust(zone, index, delta) {
                if (zone === 4) {
                    z4.keyAdjust(index, delta);
                } else if (zone === 2) {
                    z2.adjustMonth(delta);
                    root.zoneItemIndex = 1;  // focus day 1 of new month
                }
            }

            function zoneSelectableCount(zone) {
                switch (zone) {
                case 2:
                    return z2.selectableCount;
                case 3:
                    return z3.selectableCount;
                case 4:
                    return z4.selectableCount;
                case 6:
                    return z6.selectableCount;
                default:
                    return 0;
                }
            }

            function executePendingAction() {
                if (root.pendingPowerAction.length > 0) {
                    const cmd = root.pendingPowerAction;
                    // Lock and sleep both leave the session alive and resume to the same
                    // desktop, so any mid-animation compositor frames will ghost on resume.
                    const needsInstantClose = (cmd.length === 1 && cmd[0] === "hyprlock") || (cmd.length === 2 && cmd[0] === "systemctl" && cmd[1] === "suspend");
                    if (needsInstantClose) {
                        panelOpenAnim.stop();
                        panelCloseAnim.stop();
                        panel.opacity = 0.0;
                        panel.scale = 0.96;
                        scrimOpenAnim.stop();
                        scrimCloseAnim.stop();
                        scrimRect.opacity = 0.0;
                        root.open = false;
                        CCState.locking();
                        lockDelay._cmd = cmd;
                        lockDelay.start();
                    } else {
                        root.open = false;
                        const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', keyArea);
                        proc.command = cmd;
                        proc.running = true;
                    }
                }
            }

            Timer {
                id: lockDelay
                interval: 50
                property var _cmd: []
                onTriggered: {
                    const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', keyArea);
                    proc.command = _cmd;
                    proc.running = true;
                }
            }

            // Panel card
            Rectangle {
                id: panel
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: win.panelW
                implicitHeight: panelCol.implicitHeight
                color: Colors.bg
                border.width: 1
                border.color: Colors.subtle

                opacity: 0.0
                scale: 0.96

                ParallelAnimation {
                    id: panelOpenAnim
                    NumberAnimation {
                        target: panel
                        property: "opacity"
                        to: 1.0
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: panel
                        property: "scale"
                        to: 1.0
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                ParallelAnimation {
                    id: panelCloseAnim
                    NumberAnimation {
                        target: panel
                        property: "opacity"
                        to: 0.0
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: panel
                        property: "scale"
                        to: 0.96
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Connections {
                    target: root
                    function onOpenChanged() {
                        if (root.open) {
                            panelCloseAnim.stop();
                            panel.opacity = 0.0;
                            panel.scale = 0.96;
                            panelOpenAnim.start();
                        } else {
                            panelOpenAnim.stop();
                            if (panel.opacity > 0)
                                panelCloseAnim.start();
                        }
                    }
                }

                Column {
                    id: panelCol
                    width: parent.width

                    StatusBar {
                        width: parent.width
                        em: win.em
                        zoneIcon: root.navMode !== "view" ? (root.zoneMeta[root.focusedZone]?.icon ?? "") : ""
                        zoneName: root.navMode !== "view" ? (root.zoneMeta[root.focusedZone]?.name ?? "") : "Control Center"
                        itemName: root.navMode === "confirm" ? (root._confirmFocus === 0 ? "Confirm" : "Cancel") : root.navMode === "zone" ? root.currentItemName(root.focusedZone, root.zoneItemIndex) : ""
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Colors.subtle
                    }

                    Row {
                        width: parent.width

                        Clock {
                            id: z0
                            width: parent.width / 2
                            em: win.em
                            zoneActive: root.navMode !== "view" && root.focusedZone === 0
                            inZoneMode: root.navMode === "zone" && root.focusedZone === 0
                            currentItemIndex: 0
                        }

                        Weather {
                            id: z1
                            width: parent.width / 2 - 1
                            em: win.em
                            zoneActive: root.navMode !== "view" && root.focusedZone === 1
                            inZoneMode: root.navMode === "zone" && root.focusedZone === 1
                            currentItemIndex: 0

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: z1.refresh()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Colors.subtle
                    }

                    Controls {
                        id: z4
                        width: parent.width
                        em: win.em
                        zoneActive: root.navMode !== "view" && root.focusedZone === 4
                        inZoneMode: root.navMode === "zone" && root.focusedZone === 4
                        currentItemIndex: root.focusedZone === 4 ? root.zoneItemIndex : 0
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Colors.subtle
                    }

                    Row {
                        width: parent.width

                        Notifications {
                            id: z3
                            width: parent.width / 2
                            em: win.em
                            zoneActive: root.navMode !== "view" && root.focusedZone === 3
                            inZoneMode: root.navMode === "zone" && root.focusedZone === 3
                            currentItemIndex: root.focusedZone === 3 ? root.zoneItemIndex : 0
                            calHeight: z2.implicitHeight
                        }

                        Rectangle {
                            width: 1
                            height: z3.height
                            color: Colors.subtle
                        }

                        Calendar {
                            id: z2
                            width: parent.width / 2 - 1
                            em: win.em
                            zoneActive: root.navMode !== "view" && root.focusedZone === 2
                            inZoneMode: root.navMode === "zone" && root.focusedZone === 2
                            currentItemIndex: root.focusedZone === 2 ? root.zoneItemIndex : 0
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Colors.subtle
                    }

                    Media {
                        id: z6
                        width: parent.width
                        em: win.em
                        zoneActive: root.navMode !== "view" && root.focusedZone === 6
                        inZoneMode: root.navMode === "zone" && root.focusedZone === 6
                        currentItemIndex: root.focusedZone === 6 ? root.zoneItemIndex : 0
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Colors.subtle
                    }

                    Metrics {
                        id: z5
                        width: parent.width
                        em: win.em
                        zoneActive: root.navMode !== "view" && root.focusedZone === 5
                        inZoneMode: false
                        currentItemIndex: 0
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Colors.subtle
                    }

                    Power {
                        id: z7
                        width: parent.width
                        em: win.em
                        zoneActive: root.navMode !== "view" && root.focusedZone >= 7 && root.focusedZone <= 10
                        focusedIndex: (root.focusedZone >= 7 && root.focusedZone <= 10) ? root.focusedZone - 7 : -1
                        confirmMode: root.navMode === "confirm"
                        onActivated: index => {
                            root.focusedZone = 7 + index;
                            root.powerColumn = index;
                            root.pendingPowerAction = z7.actionCmd(index);
                            root._confirmFocus = 0;
                            root.navMode = "confirm";
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "controlcenter"
        function toggle() {
            root.open = !root.open;
        }
    }
}
