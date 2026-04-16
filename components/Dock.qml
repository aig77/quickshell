import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "./"

PanelWindow {
    id: root

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:dock"
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: 120
    color: "transparent"

    // ── state ──────────────────────────────────────────────────────────────
    property bool dockVisible: false
    property var windowByAddress: ({})
    property bool _fetchPending: false

    // drag-to-reorder
    property int  dragIndex: -1
    property real dragDelta: 0

    // pill = exact content width; trigger = at least 4-icon wide
    readonly property real minTriggerWidth: 4 * 44 + 3 * 8 + 24   // 224px
    property real pillWidth: iconsRow.implicitWidth + 24
    property real triggerWidth: Math.max(pillWidth, minTriggerWidth)

    // ── input mask: centered strip when hidden, pill area when visible ──────
    mask: Region { item: maskRect }

    Rectangle {
        id: maskRect
        visible: false
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        width: root.triggerWidth
        height: root.dockVisible ? root.implicitHeight : 4
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on width  { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    // ── hide timer ─────────────────────────────────────────────────────────
    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.dockVisible = false
    }

    Timer {
        id: showTimer
        interval: 500
        onTriggered: if (orderedWindows.count > 0) root.dockVisible = true
    }

    // ── window model ───────────────────────────────────────────────────────
    ListModel { id: orderedWindows }

    function syncDockOrder(newList) {
        for (var i = orderedWindows.count - 1; i >= 0; i--) {
            var addr = orderedWindows.get(i).address
            if (!newList.some(function(w) { return w.address === addr }))
                orderedWindows.remove(i)
        }
        newList.forEach(function(w) {
            for (var i = 0; i < orderedWindows.count; i++) {
                if (orderedWindows.get(i).address === w.address) return
            }
            orderedWindows.append({ address: w.address })
        })
        if (orderedWindows.count === 0) root.dockVisible = false
    }

    // StdioCollector accumulates text across runs — create a fresh Process
    // instance per refresh so each fetch gets a clean collector.
    Component {
        id: clientFetcher
        Process {
            id: fetchProc
            command: ["hyprctl", "clients", "-j"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var list = JSON.parse(text)
                        var map = {}
                        list.forEach(function(w) { map[w.address] = w })
                        root.windowByAddress = map
                        root.syncDockOrder(list)
                    } catch (e) {}
                    root._fetchPending = false
                    Qt.callLater(fetchProc.destroy)
                }
            }
        }
    }

    function refreshClients() {
        if (root._fetchPending) return
        root._fetchPending = true
        clientFetcher.createObject(root)
    }

    Connections {
        target: Hyprland
        function onRawEvent() { root.refreshClients() }
    }

    Component.onCompleted: refreshClients()

    // ── centered trigger strip ─────────────────────────────────────────────
    MouseArea {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        width: root.triggerWidth
        height: 4
        hoverEnabled: true
        onEntered: { hideTimer.stop(); showTimer.restart() }
        onExited:  { showTimer.stop(); hideTimer.restart() }
    }

    // ── dock content (slides up from bottom edge) ──────────────────────────
    Item {
        anchors.fill: parent

        transform: Translate {
            y: root.dockVisible ? 0 : root.implicitHeight
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            id: dockPill
            visible: orderedWindows.count > 0
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
            width: root.pillWidth
            height: 56
            color: Colors.bg
            border.width: 2
            border.color: Colors.subtle
            radius: 20

            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            // HoverHandler is reliable across all interaction scenarios (clicking
            // into other windows, moving between icons, etc.)
            HoverHandler {
                onHoveredChanged: hovered ? (showTimer.stop(), hideTimer.stop()) : hideTimer.restart()
            }

            Row {
                id: iconsRow
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: orderedWindows

                    delegate: Item {
                        id: iconItem

                        required property string address
                        required property int index

                        property var win: root.windowByAddress[address]
                        property bool isDragging: root.dragIndex === index

                        property real iconScale: 1.0
                        Behavior on iconScale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        property real dragOffset: isDragging ? root.dragDelta : 0
                        Behavior on dragOffset {
                            enabled: !iconItem.isDragging
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        property bool tooltipVisible: false

                        Timer {
                            id: tooltipTimer
                            interval: 500
                            onTriggered: iconItem.tooltipVisible = true
                        }

                        width: 44
                        height: 44
                        z: isDragging ? 10 : 1
                        transform: Translate { x: iconItem.dragOffset }

                        Rectangle {
                            visible: iconItem.tooltipVisible && iconItem.win !== undefined
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 10
                            width: Math.min(tooltipLabel.implicitWidth + 16, 220)
                            height: tooltipLabel.implicitHeight + 10
                            radius: 8
                            color: Colors.surface
                            border.width: 1
                            border.color: Colors.subtle
                            z: 100

                            Text {
                                id: tooltipLabel
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, 204)
                                text: iconItem.win?.title ?? ""
                                color: Colors.fg
                                font { family: Colors.font; pixelSize: 12 }
                                elide: Text.ElideRight
                            }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            scale: iconItem.iconScale
                            smooth: true
                            mipmap: true
                            source: iconItem.win
                                ? Quickshell.iconPath(
                                    DesktopEntries.heuristicLookup(iconItem.win.class ?? "")?.icon
                                        ?? (iconItem.win.class ?? ""),
                                    "application-x-executable")
                                : ""
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: iconArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            property real pressSceneX: 0

                            onEntered: { iconItem.iconScale = 1.25; tooltipTimer.restart() }
                            onExited:  { iconItem.iconScale = 1.0; tooltipTimer.stop(); iconItem.tooltipVisible = false }

                            onPressed: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    pressSceneX = iconArea.mapToItem(null, mouse.x, 0).x
                                    root.dragIndex = iconItem.index
                                    root.dragDelta = 0
                                }
                            }

                            onPositionChanged: (mouse) => {
                                if (root.dragIndex === iconItem.index
                                        && (mouse.buttons & Qt.RightButton)) {
                                    root.dragDelta = iconArea.mapToItem(null, mouse.x, 0).x - pressSceneX
                                }
                            }

                            onReleased: (mouse) => {
                                if (mouse.button === Qt.RightButton
                                        && root.dragIndex === iconItem.index) {
                                    var step = iconItem.width + 8
                                    var steps = Math.round(root.dragDelta / step)
                                    var newIdx = Math.max(0,
                                        Math.min(orderedWindows.count - 1, iconItem.index + steps))
                                    if (newIdx !== iconItem.index)
                                        orderedWindows.move(iconItem.index, newIdx, 1)
                                    root.dragIndex = -1
                                    root.dragDelta = 0
                                }
                            }

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton && iconItem.win)
                                    Hyprland.dispatch("focuswindow address:" + iconItem.address)
                                else if (mouse.button === Qt.MiddleButton && iconItem.win)
                                    Hyprland.dispatch("closewindow address:" + iconItem.address)
                            }
                        }
                    }
                }
            }
        }
    }
}
