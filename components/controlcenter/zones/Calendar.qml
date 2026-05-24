pragma ComponentBehavior: Bound

import QtQuick
import "../../"

Rectangle {
    id: root

    property real em: 16
    property bool zoneActive: false
    property bool inZoneMode: false
    property int currentItemIndex: 0

    readonly property var _today: new Date()
    readonly property int _year: _today.getFullYear()
    readonly property int _month: _today.getMonth()
    readonly property int _todayDay: _today.getDate()
    readonly property int _daysInMonth: new Date(_year, _month + 1, 0).getDate()
    readonly property int _startOffset: new Date(_year, _month, 1).getDay()

    property int selectableCount: _daysInMonth

    signal activated(int index)
    signal adjustValue(int delta)

    implicitHeight: Math.round(em * 0.5)
        + Math.round(em * 1.2)
        + Math.round(em * 1.0)
        + Math.ceil((_startOffset + _daysInMonth) / 7) * Math.round(em * 1.8)
        + Math.round(em * 0.6)

    color: "transparent"
    border.width: root.zoneActive ? 2 : 0
    border.color: root.inZoneMode ? Colors.green : root.zoneActive ? Colors.blue : "transparent"

    readonly property var _dayLabels: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    Column {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Math.round(root.em * 0.6)
        }
        spacing: Math.round(root.em * 0.3)

        // Month/year header
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root._today, "MMMM yyyy")
            color: Colors.fg
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.9); bold: true }
        }

        // Day-of-week labels
        Row {
            width: parent.width
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    width: Math.round(parent.width / 7)
                    horizontalAlignment: Text.AlignHCenter
                    text: root._dayLabels[index]
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.75) }
                }
            }
        }

        // Day cells grid
        Grid {
            width: parent.width
            columns: 7

            Repeater {
                model: root._startOffset + root._daysInMonth
                delegate: Item {
                    required property int index
                    readonly property int dayNum: index - root._startOffset + 1
                    readonly property bool isDay: index >= root._startOffset
                    readonly property bool isToday: isDay && dayNum === root._todayDay
                    readonly property bool isFocused: root.inZoneMode && isDay
                        && (dayNum - 1) === root.currentItemIndex

                    width: Math.round(parent.width / 7)
                    height: Math.round(root.em * 1.8)

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(root.em * 1.6)
                        height: width
                        radius: width / 2
                        color: isToday
                            ? Qt.rgba(Colors.blue.r, Colors.blue.g, Colors.blue.b, 0.3)
                            : isFocused
                                ? Qt.rgba(Colors.green.r, Colors.green.g, Colors.green.b, 0.3)
                                : "transparent"
                        border.width: isFocused ? 1 : 0
                        border.color: Colors.green
                    }

                    Text {
                        anchors.centerIn: parent
                        text: isDay ? dayNum : ""
                        color: isToday ? Colors.blue : Colors.fg
                        font {
                            family: Colors.font
                            pixelSize: Math.round(root.em * 0.8)
                            bold: isToday
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        visible: isDay
                        onClicked: {}
                    }
                }
            }
        }
    }
}
