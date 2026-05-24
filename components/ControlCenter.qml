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
    property string navMode: "panel"   // "panel" | "zone" | "confirm"
    property int focusedZone: 0        // 0-7
    property int zoneItemIndex: 0
    property int row0Column: 0         // 0=clock, 1=weather (sticky)
    property int row1Column: 0         // 0=calendar, 1=notifications (sticky)
    property var pendingPowerAction: []

    readonly property var zoneMeta: [
        { icon: "󰅐", name: "Clock",            desc: "Current time and date"             },
        { icon: "󰖕", name: "Weather",           desc: "Current conditions"                },
        { icon: "󰃵", name: "Calendar",          desc: "Monthly view"                      },
        { icon: "󰂚", name: "Notifications",     desc: "Recent alerts"                     },
        { icon: "󰁝", name: "Controls",          desc: "Sliders, blue light, idle inhibit" },
        { icon: "󰻠", name: "Metrics",           desc: "System resource usage"             },
        { icon: "󰝚", name: "Media",             desc: "Now playing and visualizer"        },
        { icon: "⏻",  name: "Power",             desc: "Power, restart, sleep, lock"       }
    ]

    readonly property var _rows: [[0, 1], [2, 3], [4], [5], [6], [7]]

    function nextZone(current, dir) {
        let ri = _rows.findIndex(r => r.includes(current))
        ri = (ri + dir + _rows.length) % _rows.length
        const row = _rows[ri]
        if (row.length === 1) return row[0]
        if (ri === 0) return row[root.row0Column]
        return row[root.row1Column]
    }

    onOpenChanged: {
        CCState.open = open
        if (open) {
            navMode = "panel"
            focusedZone = 0
            zoneItemIndex = 0
            pendingPowerAction = []
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
            ? Math.round((screen.height - panel.implicitHeight) / 2)
            : 60

        HyprlandFocusGrab {
            id: grab
            windows: [win]
            active: root.open
            onCleared: if (!active) root.open = false
        }

        Item {
            id: keyArea
            anchors.fill: parent
            focus: root.open

            Keys.onPressed: event => {
                if (root.navMode === "panel") {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.open = false
                        event.accepted = true
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.navMode = "zone"
                        root.zoneItemIndex = 0
                        event.accepted = true
                        break
                    case Qt.Key_J:
                        root.focusedZone = root.nextZone(root.focusedZone, 1)
                        if (root.focusedZone === 0 || root.focusedZone === 1)
                            root.row0Column = root.focusedZone
                        if (root.focusedZone === 2 || root.focusedZone === 3)
                            root.row1Column = root.focusedZone - 2
                        event.accepted = true
                        break
                    case Qt.Key_K:
                        root.focusedZone = root.nextZone(root.focusedZone, -1)
                        if (root.focusedZone === 0 || root.focusedZone === 1)
                            root.row0Column = root.focusedZone
                        if (root.focusedZone === 2 || root.focusedZone === 3)
                            root.row1Column = root.focusedZone - 2
                        event.accepted = true
                        break
                    case Qt.Key_H:
                        if (root.focusedZone === 0 || root.focusedZone === 1) {
                            root.focusedZone = 1
                            root.row0Column = 1
                        }
                        if (root.focusedZone === 2 || root.focusedZone === 3) {
                            root.focusedZone = 3
                            root.row1Column = 1
                        }
                        event.accepted = true
                        break
                    case Qt.Key_L:
                        if (root.focusedZone === 0 || root.focusedZone === 1) {
                            root.focusedZone = 0
                            root.row0Column = 0
                        }
                        if (root.focusedZone === 2 || root.focusedZone === 3) {
                            root.focusedZone = 2
                            root.row1Column = 0
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
                    case Qt.Key_L:
                        zoneMove(root.focusedZone, 1)
                        event.accepted = true
                        break
                    case Qt.Key_K:
                    case Qt.Key_H:
                        zoneMove(root.focusedZone, -1)
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

            function zoneMove(zone, dir) {
                const count = zoneSelectableCount(zone)
                if (count > 0)
                    root.zoneItemIndex = (root.zoneItemIndex + dir + count) % count
            }

            function zoneActivate(zone, index) {
                if (zone === 3) {
                    const uid = CCNotifModel.items.get(index)?.uid
                    if (uid !== undefined) {
                        CCNotifModel.refs[uid]?.dismiss()
                        CCNotifModel.removeNotif(uid)
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
                if (zone === 4) z4.keyAdjust(index, delta)
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
                        'import Quickshell.Io; Process { running: true }',
                        keyArea
                    )
                    proc.command = cmd
                }
            }

            // Panel card
            Rectangle {
                id: panel
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: win.panelW
                implicitHeight: panelCol.implicitHeight
                height: Math.min(implicitHeight, win.screen ? win.screen.height * 0.85 : 800)
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
                        zoneIcon: root.zoneMeta[root.focusedZone]?.icon ?? ""
                        zoneName: root.zoneMeta[root.focusedZone]?.name ?? ""
                        zoneDesc: root.navMode === "panel"
                            ? (root.zoneMeta[root.focusedZone]?.desc ?? "")
                            : ""
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Row {
                        width: parent.width

                        Clock {
                            id: z0
                            width: parent.width / 2
                            em: win.em
                            zoneActive: root.focusedZone === 0
                            inZoneMode: root.navMode === "zone" && root.focusedZone === 0
                            currentItemIndex: 0
                        }

                        Weather {
                            id: z1
                            width: parent.width / 2 - 1
                            em: win.em
                            zoneActive: root.focusedZone === 1
                            inZoneMode: root.navMode === "zone" && root.focusedZone === 1
                            currentItemIndex: 0
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Row {
                        width: parent.width

                        Calendar {
                            id: z2
                            width: parent.width / 2
                            em: win.em
                            zoneActive: root.focusedZone === 2
                            inZoneMode: root.navMode === "zone" && root.focusedZone === 2
                            currentItemIndex: root.focusedZone === 2 ? root.zoneItemIndex : 0
                        }

                        Rectangle { width: 1; height: z2.height; color: Colors.subtle }

                        Notifications {
                            id: z3
                            width: parent.width / 2 - 1
                            em: win.em
                            zoneActive: root.focusedZone === 3
                            inZoneMode: root.navMode === "zone" && root.focusedZone === 3
                            currentItemIndex: root.focusedZone === 3 ? root.zoneItemIndex : 0
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Sliders {
                        id: z4
                        width: parent.width
                        em: win.em
                        zoneActive: root.focusedZone === 4
                        inZoneMode: root.navMode === "zone" && root.focusedZone === 4
                        currentItemIndex: root.focusedZone === 4 ? root.zoneItemIndex : 0
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Metrics {
                        id: z5
                        width: parent.width
                        em: win.em
                        zoneActive: root.focusedZone === 5
                        inZoneMode: false
                        currentItemIndex: 0
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Media {
                        id: z6
                        width: parent.width
                        em: win.em
                        zoneActive: root.focusedZone === 6
                        inZoneMode: root.navMode === "zone" && root.focusedZone === 6
                        currentItemIndex: root.focusedZone === 6 ? root.zoneItemIndex : 0
                    }

                    Rectangle { width: parent.width; height: 1; color: Colors.subtle }

                    Power {
                        id: z7
                        width: parent.width
                        em: win.em
                        zoneActive: root.focusedZone === 7
                        inZoneMode: root.navMode === "zone" && root.focusedZone === 7
                        confirmMode: root.navMode === "confirm"
                        currentItemIndex: root.focusedZone === 7 ? root.zoneItemIndex : 0
                        onConfirmed: cmd => {
                            root.open = false
                            const proc = Qt.createQmlObject(
                                'import Quickshell.Io; Process { running: true }',
                                keyArea
                            )
                            proc.command = cmd
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
