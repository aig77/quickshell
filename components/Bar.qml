import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "./"

PanelWindow {
  id: root

  property int fontSize: 16

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: 46
  color: "transparent"

  // Center module
  Rectangle {
    anchors.top: parent.top
    anchors.topMargin: 10
    anchors.horizontalCenter: parent.horizontalCenter
    color: Colors.bg
    border.width: 2
    border.color: Colors.subtle
    implicitWidth: row.implicitWidth + 40
    height: 36
    radius: 20

    RowLayout {
      id: row
      anchors.centerIn: parent
      spacing: 8

      // Clock
      Text {
        id: clock
        color: Colors.fg
        font { family: Colors.font; pixelSize: root.fontSize; bold: true }
        text: Qt.formatDateTime(new Date(), "HH:mm")
        Timer {
          interval: 1000
          running: true
          repeat: true
          onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm")
        }
      }

      Item { width: 2 }

      // Workspaces
      Row {
        spacing: 0

        Repeater {
          model: 5

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

              MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace" + (index + 1))
              }
            }
          }
        }
      }
    }
  }
}
