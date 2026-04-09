pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "./"

Scope {
    id: root

    property bool open: false
    property int selectedIndex: -1

    property var filteredApps: {
        const q = searchInput.text.toLowerCase().trim()
        if (q === "") return []
        const all = DesktopEntries.applications?.values ?? []
        return all
            .filter(e => !e.noDisplay && (
                (e.name ?? "").toLowerCase().includes(q) ||
                (e.genericName ?? "").toLowerCase().includes(q) ||
                (e.id ?? "").toLowerCase().includes(q) ||
                (e.keywords ?? []).some(k => k.toLowerCase().includes(q))
            ))
            .sort((a, b) => {
                const an = (a.name ?? "").toLowerCase()
                const bn = (b.name ?? "").toLowerCase()
                return (an.startsWith(q) ? 0 : 1) - (bn.startsWith(q) ? 0 : 1)
                    || an.localeCompare(bn)
            })
            .slice(0, 8)
    }

    onFilteredAppsChanged: selectedIndex = filteredApps.length > 0 ? 0 : -1

    function launchApp(entry) {
        if (!entry) return
        const cmd = entry.command
        if (!cmd || cmd.length === 0) return
        const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        proc.command = cmd
        proc.running = true
        open = false
    }

    PanelWindow {
        id: win
        anchors.top: true
        WlrLayershell.margins.top: win.screen ? Math.round(win.screen.height * 0.25) : 360
        implicitWidth: win.screen ? Math.max(Math.min(Math.round(win.screen.width * 0.36), 722), 504) : 600
        implicitHeight: 60 + 8 * 54 + 9
        color: "transparent"
        visible: root.open

        WlrLayershell.namespace: "quickshell:launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        HyprlandFocusGrab {
            id: grab
            windows: [win]
            active: root.open
            onCleared: if (!active) root.open = false
        }

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) {
                    searchInput.forceActiveFocus()
                } else {
                    searchInput.text = ""
                    root.selectedIndex = -1
                }
            }
        }


        Item {
            anchors.fill: parent
            focus: root.open

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                    root.open = false
                    event.accepted = true
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (root.selectedIndex >= 0 && root.selectedIndex < root.filteredApps.length)
                        root.launchApp(root.filteredApps[root.selectedIndex])
                    event.accepted = true
                    break
                case Qt.Key_Down:
                    root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredApps.length - 1)
                    event.accepted = true
                    break
                case Qt.Key_Up:
                    root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                    event.accepted = true
                    break
                }
            }

            Rectangle {
                id: pill
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: searchRow.height
                    + (root.filteredApps.length > 0 ? resultsContainer.implicitHeight : 0)

                Behavior on implicitHeight {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                radius: 30
                color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.85)
                border.width: 2
                border.color: Colors.subtle
                clip: true

                Item {
                    id: searchRow
                    width: pill.width
                    height: 60

                    Text {
                        id: searchIcon
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        text: "󰍉"
                        font.family: Colors.font
                        font.pixelSize: 24
                        color: Colors.muted
                    }

                    TextInput {
                        id: searchInput
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: searchIcon.right
                        anchors.right: parent.right
                        anchors.leftMargin: 14
                        anchors.rightMargin: 24
                        font.family: Colors.font
                        font.pixelSize: 20
                        color: Colors.fg
                        selectionColor: Qt.rgba(Colors.blue.r, Colors.blue.g, Colors.blue.b, 0.4)
                        selectedTextColor: Colors.fg
                        focus: root.open
                        selectByMouse: true
                        clip: true
                    }
                }

                Column {
                    id: resultsContainer
                    anchors.top: searchRow.bottom
                    width: pill.width
                    bottomPadding: root.filteredApps.length > 0 ? 9 : 0

                    Repeater {
                        model: root.filteredApps
                        delegate: Item {
                            id: resultRow
                            required property var modelData
                            required property int index

                            width: resultsContainer.width
                            height: 54

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 2
                                anchors.rightMargin: 2
                                bottomLeftRadius: resultRow.index === root.filteredApps.length - 1 ? 28 : 0
                                bottomRightRadius: resultRow.index === root.filteredApps.length - 1 ? 28 : 0
                                color: resultRow.index === root.selectedIndex
                                    ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1.0)
                                    : "transparent"
                            }

                            Image {
                                id: appIcon
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 17
                                source: Quickshell.iconPath(
                                    resultRow.modelData.icon ?? resultRow.modelData.id ?? "",
                                    "application-x-executable"
                                )
                                width: 34; height: 34
                                sourceSize: Qt.size(34, 34)
                                smooth: true
                                mipmap: true
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: appIcon.right
                                anchors.leftMargin: 14
                                spacing: 2

                                Text {
                                    text: resultRow.modelData.name ?? ""
                                    font.family: Colors.font
                                    font.pixelSize: 17
                                    font.weight: Font.Medium
                                    color: Colors.fg
                                }

                                Text {
                                    text: resultRow.modelData.genericName ?? resultRow.modelData.comment ?? ""
                                    font.family: Colors.font
                                    font.pixelSize: 13
                                    color: Colors.subtle
                                    visible: text.length > 0
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selectedIndex = resultRow.index
                                onClicked: root.launchApp(resultRow.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle() { root.open = !root.open }
    }
}
