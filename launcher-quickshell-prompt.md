# Task: Build a macOS Spotlight-style App Launcher in Quickshell

## Goal

Build a new self-contained `launcher` module at `/home/arturo/.config/quickshell/launcher/`.

The launcher behaves like macOS Spotlight:
- Opens as a single pill-shaped search bar, positioned slightly above screen center
- As the user types, matching apps appear below (window expands downward with animation)
- Arrow keys navigate results, Enter launches, Escape closes, clicking outside closes
- App icons shown per result row

**The module must be 100% self-contained. It only imports from Qt/Quickshell builtins and `Colors.qml` (the top-level singleton at `/home/arturo/.config/quickshell/Colors.qml`). It does NOT import from or modify anything in `./overview/`.**

---

## Codebase Context

```
/home/arturo/.config/quickshell/
├── shell.qml       ← only file outside launcher/ to modify
├── Colors.qml      ← the only external dependency to import
├── Bar.qml         ← reference: simple PanelWindow example
├── notifications/  ← reference: self-contained module pattern
└── overview/       ← DO NOT TOUCH
```

### How `shell.qml` currently looks (for context only):
```qml
//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import Quickshell
import "./"
import "./overview/modules/overview/"
import "./overview/services/"
import "./overview/common/"
import "./overview/common/functions/"
import "./overview/common/widgets/"
import "./notifications/"

ShellRoot {
  Bar {}
  Overview {}
  NotificationStack {}
}
```

Add `import "./launcher/"` and `Launcher {}` inside `ShellRoot`. Touch nothing else.

---

## Files to Create

### `/home/arturo/.config/quickshell/launcher/qmldir`
```
module launcher
Launcher 1.0 Launcher.qml
```

### `/home/arturo/.config/quickshell/launcher/Launcher.qml`

Full spec below.

---

## Colors.qml API

Import from launcher/ with `import "../"`. It is a `pragma Singleton` named `Colors`.

```
Colors.bg       #1e1e2e  darkest background
Colors.mantle   #181825
Colors.surface  #313244  card surface / selection bg
Colors.muted    #45475a  muted text, icons
Colors.subtle   #585b70  borders, dividers
Colors.fg       #cdd6f4  primary text
Colors.blue     #89b4fa  accent / active selection
Colors.purple   #cba4f7
Colors.font     "JetBrainsMono Nerd Font"
```

Semi-transparent background: `Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.92)`

---

## Launcher.qml Spec

### Imports
```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"
```

### Skeleton
```
Scope
  ├── property bool open: false          ← all state lives here
  ├── property int selectedIndex: -1
  ├── property var filteredApps: [...]   ← computed from search text
  ├── function launchApp(entry) { ... }
  │
  ├── PanelWindow (full-screen transparent overlay)
  │   ├── HyprlandFocusGrab
  │   ├── Timer (delayed grab activation)
  │   ├── Connections (reset state on close)
  │   └── Item (keyHandler, anchors.fill)
  │       ├── MouseArea (z:-1, click outside → close)
  │       └── Rectangle pill (anchored horizontalCenter, y: parent.height*0.33)
  │           ├── Item searchRow (height 60)
  │           │   ├── Text "󰍉" (icon)
  │           │   └── TextInput searchInput
  │           ├── Rectangle divider (height 1, visible when results > 0)
  │           └── Column resultsContainer
  │               └── Repeater → delegate rows (icon + name + genericName)
  │
  └── IpcHandler { target: "launcher" }
```

### PanelWindow

```qml
PanelWindow {
    id: win
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    visible: open

    WlrLayershell.namespace: "quickshell:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
```

**Why full-screen transparent:** Wayland layer-shell has no "floating at arbitrary coordinates" — the standard pattern is a full-screen transparent window with content positioned inside at the desired coordinates.

### HyprlandFocusGrab + activation timer

```qml
HyprlandFocusGrab {
    id: grab
    windows: [win]
    active: false
    onCleared: if (!active) open = false
}

Timer {
    id: grabTimer
    interval: 150
    repeat: false
    onTriggered: grab.active = open
}

Connections {
    target: /* the parent Scope */
    function onOpenChanged() {
        if (open) {
            grabTimer.start()
        } else {
            grab.active = false
            searchInput.text = ""
            selectedIndex = -1
        }
    }
}
```

The 150ms delay is necessary to avoid a Hyprland race condition where the window hasn't mapped yet when grab is activated (same pattern used by other layer-shell overlays in this codebase).

### Key handling

```qml
Item {
    id: keyHandler
    anchors.fill: parent
    focus: open

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
            open = false
            event.accepted = true
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (selectedIndex >= 0 && selectedIndex < filteredApps.length)
                launchApp(filteredApps[selectedIndex])
            event.accepted = true
            break
        case Qt.Key_Down:
            selectedIndex = Math.min(selectedIndex + 1, filteredApps.length - 1)
            event.accepted = true
            break
        case Qt.Key_Up:
            selectedIndex = Math.max(selectedIndex - 1, 0)
            event.accepted = true
            break
        // Do NOT set accepted for other keys — TextInput must receive them
        }
    }
}
```

### The pill

```qml
Rectangle {
    id: pill
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height * 0.33
    width: Math.max(Math.min(parent.width * 0.38, 720), 500)
    implicitHeight: searchRow.height
                  + (filteredApps.length > 0 ? 1 : 0)   // divider
                  + resultsContainer.implicitHeight
    radius: 30
    color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.92)
    border.color: Qt.rgba(Colors.subtle.r, Colors.subtle.g, Colors.subtle.b, 0.45)
    border.width: 1
    clip: true   // required — prevents results from rendering outside pill during animation

    Behavior on implicitHeight {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
}
```

### Search bar row

Use `TextInput` (not `TextField`) — bare `TextInput` has no implicit styling overhead.

```qml
Item {
    id: searchRow
    width: pill.width
    height: 60

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 14

        Text {
            text: "\uDB80\uDC89"  // or use the literal  from Nerd Font
            font.family: Colors.font
            font.pixelSize: 20
            color: Colors.muted
            anchors.verticalCenter: parent.verticalCenter
        }

        TextInput {
            id: searchInput
            width: parent.width - 46
            font.family: Colors.font
            font.pixelSize: 16
            color: Colors.fg
            focus: open
            selectByMouse: true
        }
    }
}
```

### Results list

```qml
Column {
    id: resultsContainer
    anchors.top: searchRow.bottom
    anchors.topMargin: filteredApps.length > 0 ? 1 : 0
    width: pill.width
    // implicitHeight is the sum of all delegate heights — drives pill Behavior

    Repeater {
        model: filteredApps
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: resultsContainer.width
            height: 52
            color: index === selectedIndex
                ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1.0)
                : "transparent"
            radius: 8

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 16
                spacing: 14

                Image {
                    source: Quickshell.iconPath(
                        modelData.icon ?? modelData.id ?? "application-x-executable",
                        "image-missing"
                    )
                    width: 32; height: 32
                    sourceSize: Qt.size(32, 32)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: modelData.name ?? modelData.id ?? ""
                        font.family: Colors.font
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: Colors.fg
                    }

                    Text {
                        text: modelData.genericName ?? modelData.comment ?? ""
                        font.family: Colors.font
                        font.pixelSize: 12
                        color: Colors.muted
                        visible: text.length > 0
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: selectedIndex = index
                onClicked: launchApp(modelData)
            }
        }
    }
}
```

### App filtering

```qml
property var filteredApps: {
    const q = searchInput.text.toLowerCase().trim()
    if (q === "") return []
    const all = DesktopEntries.applications.values   // may be plain array — remove .values if undefined
    return all
        .filter(e => !e.noDisplay && (
            (e.name ?? "").toLowerCase().includes(q) ||
            (e.genericName ?? "").toLowerCase().includes(q) ||
            (e.id ?? "").toLowerCase().includes(q)
        ))
        .sort((a, b) => {
            const an = (a.name ?? "").toLowerCase()
            const bn = (b.name ?? "").toLowerCase()
            return (an.startsWith(q) ? 0 : 1) - (bn.startsWith(q) ? 0 : 1) || an.localeCompare(bn)
        })
        .slice(0, 8)
}

onFilteredAppsChanged: selectedIndex = filteredApps.length > 0 ? 0 : -1
```

### App launching

```qml
Process {
    id: launchProc
}

function launchApp(entry) {
    const raw = entry.execString ?? entry.exec ?? ""
    const cmd = raw.replace(/%[fFuUdDnNickvm]/g, "").trim()
    if (cmd) {
        launchProc.command = cmd.split(/\s+/)
        launchProc.running = true
    }
    open = false
}
```

### IpcHandler

```qml
IpcHandler {
    target: "launcher"
    function toggle() { open = !open }
    function open()   { open = true }
    function close()  { open = false }
}
```

Triggered from Hyprland keybind: `qs ipc call launcher toggle`

---

## Hyprland Keybind

After building, find the fuzzel keybind in `/home/arturo/.config/bebop/modules/hyprland/home.nix` and add/replace with:
```
bind = $mainMod, Space, exec, qs ipc call launcher toggle
```
Check the existing fuzzel bind for the correct key combination.

---

## Rules

- No imports from `./overview/` anywhere
- No `TextField` — use `TextInput` inside a styled `Rectangle`
- PanelWindow must be full-screen transparent; pill is positioned inside it
- All state (`open`, `selectedIndex`, `filteredApps`) lives on the top-level `Scope`
- `clip: true` on the pill is required for the height animation to look correct

---

## Verification

1. `qs` reloads without errors
2. `qs ipc call launcher toggle` opens the launcher
3. Launcher is a single pill, ~33% down from screen top, horizontally centered
4. Typing filters apps and window expands downward smoothly
5. Arrow keys move selection, Enter launches, Escape closes
6. Clicking outside the pill closes it
7. Re-opening after close shows empty search bar
