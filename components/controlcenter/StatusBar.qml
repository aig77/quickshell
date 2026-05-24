import QtQuick
import "../"

Rectangle {
    id: root

    property string zoneIcon: ""
    property string zoneName: ""
    property string zoneDesc: ""
    property real em: 16

    height: Math.round(em * 2.4)
    color: "transparent"

    Row {
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: Math.round(root.em * 1.2)
        }
        spacing: Math.round(root.em * 0.6)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.zoneIcon
            color: Colors.blue
            font { family: Colors.font; pixelSize: Math.round(root.em * 1.1) }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.zoneName
            color: Colors.blue
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.9); bold: true }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "|"
            color: Colors.muted
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }
            visible: root.zoneDesc.length > 0
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.zoneDesc
            color: Colors.muted
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }
            visible: root.zoneDesc.length > 0
        }
    }
}
