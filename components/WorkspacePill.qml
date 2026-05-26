import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "./"
import "./controlcenter/"
import "./overview/common/"

PanelWindow {
  id: root

  property bool showing: false
  property bool forceShow: false
  property int fontSize: 14

  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  implicitHeight: 80
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "quickshell:workspacepill"
  mask: Region { item: (root.showing || root.forceShow) ? pill : null }

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

    opacity: 0.0
    transform: Translate { id: pillTranslate; y: 16 }

    NumberAnimation { id: pillShowOpacity;  target: pill;          property: "opacity"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
    NumberAnimation { id: pillHideOpacity;  target: pill;          property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.OutCubic }
    NumberAnimation { id: pillSlideIn;      target: pillTranslate; property: "y";       to: 0;   duration: 200; easing.type: Easing.OutCubic }
    NumberAnimation { id: pillSlideOut;     target: pillTranslate; property: "y";       to: 16;  duration: 200; easing.type: Easing.OutCubic }

    function updateVisibility() {
      const vis = root.showing || root.forceShow
      if (vis) {
        pillHideOpacity.stop()
        pillSlideOut.stop()
        pill.opacity = 0.0
        pillTranslate.y = 16
        pillShowOpacity.start()
        pillSlideIn.start()
      } else {
        pillShowOpacity.stop()
        pillSlideIn.stop()
        pillHideOpacity.start()
        pillSlideOut.start()
      }
    }

    Connections {
      target: root
      function onShowingChanged()   { pill.updateVisibility() }
      function onForceShowChanged() { pill.updateVisibility() }
    }

    Connections {
      target: CCState
      function onOpenChanged() { root.forceShow = CCState.open }
      function onLocking() {
        pillShowOpacity.stop()
        pillSlideIn.stop()
        pillHideOpacity.stop()
        pillSlideOut.stop()
        pill.opacity = 0.0
        pillTranslate.y = 16
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
          model: Config.options.overview.columns * Config.options.overview.rows

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
