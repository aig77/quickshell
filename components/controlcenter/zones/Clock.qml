import QtQuick
import "../.."

Rectangle {
    id: root

    property real em: 16
    property bool zoneActive: false
    property bool inZoneMode: false
    property int currentItemIndex: 0
    property int selectableCount: 0

    signal activated(int index)
    signal adjustValue(int delta)

    implicitHeight: Math.round(em * 6)
    color: "transparent"
    border.width: root.zoneActive ? 2 : 0
    border.color: root.inZoneMode ? Colors.green : root.zoneActive ? Colors.blue : "transparent"

    property string _time: Qt.formatDateTime(new Date(), "HH:mm")
    property string _date: Qt.formatDateTime(new Date(), "dddd, MMMM d")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root._time = Qt.formatDateTime(new Date(), "HH:mm")
            root._date = Qt.formatDateTime(new Date(), "dddd, MMMM d")
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.round(root.em * 0.2)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._time
            color: Colors.fg
            font { family: Colors.font; pixelSize: Math.round(root.em * 3) }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._date
            color: Colors.muted
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.9) }
        }
    }
}
