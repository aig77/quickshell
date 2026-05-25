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
    property int focusedZone: 0        // 0-7
    property int zoneItemIndex: 0
    property int row0Column: 0         // 0=clock, 1=weather (sticky)
    property int row1Column: 0         // 0=calendar, 1=notifications (sticky)
    property var pendingPowerAction: []

    // Notification whose body is shown in the detail popup (keyboard focus or mouse hover)
    readonly property var _popupNotif: {
        if (!root.open) return null
        if (root.navMode === "zone" && root.focusedZone === 3) {
            if (root.zoneItemIndex >= CCNotifModel.items.count) return null
            return CCNotifModel.items.get(root.zoneItemIndex) ?? null
        }
        const hi = z3.hoveredIndex
        if (hi >= 0) return CCNotifModel.items.get(hi) ?? null
        return null
    }

    readonly property var zoneMeta: [
        { icon: "󰅐", name: "Clock",            },
        { icon: "󰖕", name: "Weather",           },
        { icon: "󰃵", name: "Calendar",          },
        { icon: "󰂚", name: "Notifications",     },
        { icon: "󰁝", name: "Controls",          },
        { icon: "󰻠", name: "Metrics",           },
        { icon: "󰝚", name: "Media",             },
        { icon: "⏻",  name: "Power",             }
    ]

    // Row order matches visual layout: Clock/Weather | Metrics | Calendar/Notifications | Controls | Media | Power
    readonly property var _rows: [[0, 1], [5], [2, 3], [4], [6], [7]]

    function nextZone(current, dir) {
        let ri = _rows.findIndex(r => r.includes(current))
        let zone
        let attempts = 0
        do {
            ri = (ri + dir + _rows.length) % _rows.length
            const row = _rows[ri]
            if (row.length === 1) {
                zone = row[0]
            } else if (ri === 0) {
                zone = row[root.row0Column]
            } else {
                zone = row[root.row1Column]
            }
            attempts++
        } while ([0, 1, 5].includes(zone) && attempts < _rows.length)
        return zone
    }

    function currentItemName(zone, index) {
        switch (zone) {
            case 2: {
                if (index === 0) return "Prev Month"
                if (index === z2._daysInMonth + 1) return "Next Month"
                return "Day " + index
            }
            case 3: {
                if (index === CCNotifModel.items.count) return "Clear All"
                const notif = CCNotifModel.items.get(index)
                if (!notif) return ""
                const s = notif.appName
                return s.length > 22 ? s.substring(0, 19) + "..." : s
            }
            case 4: return (["Volume", "Brightness", "Blue Light", "Idle Inhibit"])[index] ?? ""
            case 6: return (["Previous", "Play/Pause", "Next"])[index] ?? ""
            case 7: return (["Power", "Restart", "Sleep", "Lock"])[index] ?? ""
            default: return ""
        }
    }

    onOpenChanged: {
        CCState.open = open
        if (open) {
            navMode = "view"
            focusedZone = 0
            zoneItemIndex = 0
            pendingPowerAction = []
        }
    }

    // --- Notification detail popup: appears to the right of the panel ---
    PanelWindow {
        id: popupWin
        anchors.left: true
        anchors.top: true
        visible: root.open && root._popupNotif !== null
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:controlcenter:notifdetail"

        readonly property real em: screen ? Math.round(screen.height * 0.018) : 16
        readonly property real _panelW: screen ? Math.min(Math.round(screen.width * 0.4), 600) : 480

        // Height of everything below the notification zone (sliders + media + power + 3 separators)
        readonly property real _belowNotifH: Math.round(win.em * 6) + Math.round(win.em * 9.8) + Math.round(win.em * 4.5) + 3
        readonly property real _notifZoneH: z2.implicitHeight
        readonly property real _notifZoneTopY: screen
            ? Math.round((screen.height - panel.implicitHeight) / 2)
              + panel.implicitHeight - _belowNotifH - _notifZoneH
            : 200

        implicitWidth: Math.round(em * 16)
        implicitHeight: popupCard.implicitHeight

        WlrLayershell.margins.left: screen
            ? Math.round(screen.width / 2 + _panelW / 2) + Math.round(em * 0.5)
            : 400
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
                    font { family: Colors.font; pixelSize: Math.round(popupWin.em * 0.85); bold: true }
                    wrapMode: Text.WordWrap
                    visible: (root._popupNotif?.summary ?? "").length > 0
                }

                Text {
                    width: parent.width
                    text: root._popupNotif?.body ?? ""
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(popupWin.em * 0.8) }
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
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:controlcenter:powerconfirm"

        readonly property real em: screen ? Math.round(screen.height * 0.018) : 16
        readonly property real _panelW: screen ? Math.min(Math.round(screen.width * 0.4), 600) : 480
        readonly property var _actionColors: [Colors.red, Colors.blue, Colors.purple, Colors.green]
        readonly property real _zoneH: Math.round(win.em * 4.5)

        // Top of the power zone
        readonly property real _powerZoneTopY: screen
            ? Math.round((screen.height - panel.implicitHeight) / 2)
              + panel.implicitHeight - _zoneH
            : 300

        implicitWidth: Math.round(em * 7)
        implicitHeight: _zoneH

        WlrLayershell.margins.left: screen
            ? Math.round(screen.width / 2 + _panelW / 2) + Math.round(em * 0.5)
            : 400
        WlrLayershell.margins.top: Math.round(_powerZoneTopY)

        Rectangle {
            id: pcCard
            anchors.fill: parent
            color: Colors.bg
            border.width: 1
            border.color: Colors.subtle

            Column {
                id: pcCol
                anchors.centerIn: parent
                spacing: Math.round(powerConfirmWin.em * 0.7)

                Text {
                    text: "Confirm"
                    color: powerConfirmWin._actionColors[root.zoneItemIndex] ?? Colors.fg
                    font { family: Colors.font; pixelSize: Math.round(powerConfirmWin.em * 0.85); bold: true }
                    horizontalAlignment: Text.AlignHCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.pendingPowerAction.length > 0) {
                                const cmd = root.pendingPowerAction
                                root.open = false
                                const proc = Qt.createQmlObject(
                                    'import Quickshell.Io; Process {}', powerConfirmWin)
                                proc.command = cmd
                                proc.running = true
                            }
                        }
                    }
                }

                Text {
                    text: "Cancel"
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(powerConfirmWin.em * 0.85) }
                    horizontalAlignment: Text.AlignHCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.navMode = "zone"
                            root.pendingPowerAction = []
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
        visible: root.open
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:controlcenter:scrim"

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)

            opacity: root.open ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }
        }
    }

    // --- Panel window: WlrLayer.Overlay, always above scrim ---
    PanelWindow {
        id: win
        anchors.top: true
        color: "transparent"
        visible: root.open
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell:controlcenter"

        readonly property real em: screen ? Math.round(screen.height * 0.018) : 16
        readonly property real panelW: screen
            ? Math.min(Math.round(screen.width * 0.4), 600)
            : 480

        implicitWidth: panelW
        implicitHeight: screen ? screen.height : 1080

        WlrLayershell.margins.top: screen && panel.implicitHeight > 0
            ? Math.round((screen.height - panel.height) / 2)
            : 60

        HyprlandFocusGrab {
            id: grab
            windows: [win, popupWin, powerConfirmWin]
            active: root.open
            onCleared: if (!active) root.open = false
        }

        Item {
            id: keyArea
            anchors.fill: parent
            focus: root.open

            Keys.onPressed: event => {
                if (root.navMode === "view") {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.open = false
                        event.accepted = true
                        break
                    case Qt.Key_J:
                    case Qt.Key_K:
                    case Qt.Key_H:
                    case Qt.Key_L:
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.navMode = "panel"
                        root.focusedZone = 2
                        root.row1Column = 0
                        event.accepted = true
                        break
                    }
                } else if (root.navMode === "panel") {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.open = false
                        event.accepted = true
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (zoneSelectableCount(root.focusedZone) > 0) {
                            root.navMode = "zone"
                            root.zoneItemIndex = 0
                        }
                        event.accepted = true
                        break
                    case Qt.Key_J:
                        root.focusedZone = root.nextZone(root.focusedZone, 1)
                        if (root.focusedZone === 2 || root.focusedZone === 3)
                            root.row1Column = root.focusedZone - 2
                        event.accepted = true
                        break
                    case Qt.Key_K:
                        root.focusedZone = root.nextZone(root.focusedZone, -1)
                        if (root.focusedZone === 2 || root.focusedZone === 3)
                            root.row1Column = root.focusedZone - 2
                        event.accepted = true
                        break
                    case Qt.Key_H:
                        if (root.focusedZone === 2 || root.focusedZone === 3) {
                            root.focusedZone = 2
                            root.row1Column = 0
                        }
                        event.accepted = true
                        break
                    case Qt.Key_L:
                        if (root.focusedZone === 2 || root.focusedZone === 3) {
                            root.focusedZone = 3
                            root.row1Column = 1
                        }
                        event.accepted = true
                        break
                    }
                } else if (root.navMode === "zone") {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.navMode = "panel"
                        event.accepted = true
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        zoneActivate(root.focusedZone, root.zoneItemIndex)
                        event.accepted = true
                        break
                    case Qt.Key_J:
                        zoneMoveDir(root.focusedZone, 0, 1)
                        event.accepted = true
                        break
                    case Qt.Key_K:
                        zoneMoveDir(root.focusedZone, 0, -1)
                        event.accepted = true
                        break
                    case Qt.Key_L:
                        zoneMoveDir(root.focusedZone, 1, 0)
                        event.accepted = true
                        break
                    case Qt.Key_H:
                        zoneMoveDir(root.focusedZone, -1, 0)
                        event.accepted = true
                        break
                    case Qt.Key_Plus:
                    case Qt.Key_Equal:
                        zoneAdjust(root.focusedZone, root.zoneItemIndex, 1)
                        event.accepted = true
                        break
                    case Qt.Key_Minus:
                        zoneAdjust(root.focusedZone, root.zoneItemIndex, -1)
                        event.accepted = true
                        break
                    case Qt.Key_Backspace:
                        if (root.focusedZone === 3 && root.zoneItemIndex < CCNotifModel.items.count) {
                            const uid = CCNotifModel.items.get(root.zoneItemIndex)?.uid
                            if (uid !== undefined) {
                                CCNotifModel.refs[uid]?.dismiss()
                                CCNotifModel.removeNotif(uid)
                                root.zoneItemIndex = Math.min(root.zoneItemIndex, z3.selectableCount - 1)
                            }
                        }
                        event.accepted = true
                        break
                    }
                } else if (root.navMode === "confirm") {
                    switch (event.key) {
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        executePendingAction()
                        event.accepted = true
                        break
                    case Qt.Key_Escape:
                        root.navMode = "zone"
                        root.pendingPowerAction = []
                        event.accepted = true
                        break
                    }
                }
            }

            function zoneMoveDir(zone, dx, dy) {
                if (zone === 2) {
                    // Calendar: header row has [prev (col 0)] and [next (col 1)].
                    // j from header enters the day grid. k from header does nothing (top).
                    // From days: k above week 1 returns to prev button; h/l = ±1 day; j/k = ±7 days.
                    const N = z2._daysInMonth
                    const cur = root.zoneItemIndex
                    if (cur === 0) {
                        // Prev button: l → next, j → first day, h/k → nothing
                        if (dx > 0) root.zoneItemIndex = N + 1
                        else if (dy > 0) root.zoneItemIndex = 1
                    } else if (cur === N + 1) {
                        // Next button: h → prev, j → first day, l/k → nothing
                        if (dx < 0) root.zoneItemIndex = 0
                        else if (dy > 0) root.zoneItemIndex = 1
                    } else {
                        // On a day: h/l = ±1 day, j/k = ±7 days (one week)
                        const step = dx !== 0 ? dx : dy * 7
                        const next = cur + step
                        if (next < 1) root.zoneItemIndex = 0
                        else if (next > N) root.zoneItemIndex = N + 1
                        else root.zoneItemIndex = next
                    }
                } else if (zone === 4) {
                    // Controls: 2x2 grid
                    // col 0: volume (0), brightness (1)
                    // col 1: blue light (2), idle inhibit (3)
                    const col = root.zoneItemIndex < 2 ? 0 : 1
                    const row = root.zoneItemIndex % 2
                    const newCol = Math.max(0, Math.min(1, col + dx))
                    const newRow = Math.max(0, Math.min(1, row + dy))
                    root.zoneItemIndex = newCol * 2 + newRow
                } else {
                    // Linear for all other zones (j/l = forward, k/h = back)
                    const dir = dx !== 0 ? dx : dy
                    const count = zoneSelectableCount(zone)
                    if (count > 0)
                        root.zoneItemIndex = (root.zoneItemIndex + dir + count) % count
                }
            }

            function zoneActivate(zone, index) {
                if (zone === 2) {
                    if (index === 0) {
                        z2.adjustMonth(-1)
                        root.zoneItemIndex = 0
                    } else if (index === z2._daysInMonth + 1) {
                        z2.adjustMonth(1)
                        root.zoneItemIndex = z2._daysInMonth + 1
                    }
                } else if (zone === 3) {
                    if (index === CCNotifModel.items.count) {
                        z3.clearAll()
                    } else {
                        const appName = CCNotifModel.items.get(index)?.appName ?? ""
                        if (appName.length > 0)
                            Hyprland.dispatch("focuswindow class:(?i)" + appName)
                        root.open = false
                    }
                } else if (zone === 4) {
                    z4.toggle(index)
                } else if (zone === 6) {
                    z6.activate(index)
                } else if (zone === 7) {
                    root.pendingPowerAction = z7.actionCmd(index)
                    root.navMode = "confirm"
                }
            }

            function zoneAdjust(zone, index, delta) {
                if (zone === 4) {
                    z4.keyAdjust(index, delta)
                } else if (zone === 2) {
                    z2.adjustMonth(delta)
                    root.zoneItemIndex = 1  // focus day 1 of new month
                }
            }

            function zoneSelectableCount(zone) {
                switch (zone) {
                    case 2: return z2.selectableCount
                    case 3: return z3.selectableCount
                    case 4: return z4.selectableCount
                    case 6: return z6.selectableCount
                    case 7: return z7.selectableCount
                    default: return 0
                }
            }

            function executePendingAction() {
                if (root.pendingPowerAction.length > 0) {
                    const cmd = root.pendingPowerAction
                    root.open = false
                    const proc = Qt.createQmlObject(
                        'import Quickshell.Io; Process {}',
                        keyArea
                    )
                    proc.command = cmd
                    proc.running = true
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

                opacity: root.open ? 1.0 : 0.0
                scale: root.open ? 1.0 : 0.96
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Column {
                    id: panelCol
                    width: parent.width

                    StatusBar {
                        width: parent.width
                        em: win.em
                        zoneIcon: root.navMode !== "view"
                            ? (root.zoneMeta[root.focusedZone]?.icon ?? "")
                            : ""
                        zoneName: root.navMode !== "view"
                            ? (root.zoneMeta[root.focusedZone]?.name ?? "")
                            : "Control Center"
                        itemName: root.navMode === "zone"
                            ? root.currentItemName(root.focusedZone, root.zoneItemIndex)
                            : ""
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

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
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Metrics {
                        id: z5
                        width: parent.width
                        em: win.em
                        zoneActive: root.navMode !== "view" && root.focusedZone === 5
                        inZoneMode: false
                        currentItemIndex: 0
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Row {
                        width: parent.width

                        Calendar {
                            id: z2
                            width: parent.width / 2
                            em: win.em
                            zoneActive: root.navMode !== "view" && root.focusedZone === 2
                            inZoneMode: root.navMode === "zone" && root.focusedZone === 2
                            currentItemIndex: root.focusedZone === 2 ? root.zoneItemIndex : 0
                        }

                        Rectangle { width: 1; height: z2.height; color: Colors.subtle }

                        Notifications {
                            id: z3
                            width: parent.width / 2 - 1
                            em: win.em
                            zoneActive: root.navMode !== "view" && root.focusedZone === 3
                            inZoneMode: root.navMode === "zone" && root.focusedZone === 3
                            currentItemIndex: root.focusedZone === 3 ? root.zoneItemIndex : 0
                            calHeight: z2.implicitHeight
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Controls {
                        id: z4
                        width: parent.width
                        em: win.em
                        zoneActive: root.navMode !== "view" && root.focusedZone === 4
                        inZoneMode: root.navMode === "zone" && root.focusedZone === 4
                        currentItemIndex: root.focusedZone === 4 ? root.zoneItemIndex : 0
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Media {
                        id: z6
                        width: parent.width
                        em: win.em
                        zoneActive: root.navMode !== "view" && root.focusedZone === 6
                        inZoneMode: root.navMode === "zone" && root.focusedZone === 6
                        currentItemIndex: root.focusedZone === 6 ? root.zoneItemIndex : 0
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Power {
                        id: z7
                        width: parent.width
                        em: win.em
                        zoneActive: root.navMode !== "view" && root.focusedZone === 7
                        inZoneMode: root.navMode === "zone" && root.focusedZone === 7
                        confirmMode: root.navMode === "confirm"
                        currentItemIndex: root.focusedZone === 7 ? root.zoneItemIndex : 0
                        onActivated: index => {
                            root.focusedZone = 7
                            root.zoneItemIndex = index
                            root.pendingPowerAction = z7.actionCmd(index)
                            root.navMode = "confirm"
                        }
                    }
                }
            }

        }
    }

    IpcHandler {
        target: "controlcenter"
        function toggle() { root.open = !root.open }
    }
}
