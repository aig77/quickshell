import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "./"

PanelWindow {
  id: root

  property bool showing: false
  property int fontSize: 14

  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  implicitHeight: 80
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "quickshell:workspacepill"
  mask: Region { item: root.showing ? pill : null }

  Timer {
    id: hideTimer
    interval: 2000
    onTriggered: root.showing = false
  }

  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      root.showing = true
      hideTimer.restart()
    }
  }

  Column {
    id: pill
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 4

    opacity: root.showing ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    transform: Translate {
      y: root.showing ? 0 : 16
      Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    // Clock (bare text, no pill)
    Text {
      id: clock
      anchors.horizontalCenter: parent.horizontalCenter
      color: Colors.muted
      font { family: Colors.font; pixelSize: root.fontSize }
      text: Qt.formatDateTime(new Date(), "HH:mm")
      Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm")
      }
    }

    // Workspace pill
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.85)
      border.width: 1
      border.color: Colors.subtle
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.4)
        shadowBlur: 0.8
      }
      implicitWidth: workspaces.implicitWidth + 40
      height: 36
      radius: 20

      Row {
        id: workspaces
        anchors.centerIn: parent
        spacing: 0

        Repeater {
          model: 10

          Item {
            property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
            property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)

            width: isActive ? 38 : 22
            height: 14

            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

            Rectangle {
              anchors.centerIn: parent
              width: isActive ? 32 : 14
              height: 14
              radius: height / 2
              color: isActive ? Colors.blue : (ws ? Colors.purple : Colors.muted)

              Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
            }
          }
        }
      }
    }
  }
}
