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
    readonly property int _todayYear: _today.getFullYear()
    readonly property int _todayMonth: _today.getMonth()
    readonly property int _todayDay: _today.getDate()

    // View state: which month/year is displayed
    property int viewYear: _todayYear
    property int viewMonth: _todayMonth

    readonly property int _daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()
    readonly property int _startOffset: new Date(viewYear, viewMonth, 1).getDay()
    readonly property bool _isCurrentMonth: viewYear === _todayYear && viewMonth === _todayMonth

    // Selectable items: index 0 = prev month button, 1..daysInMonth = days, daysInMonth+1 = next month button
    property int selectableCount: _daysInMonth + 2

    signal activated(int index)
    signal adjustValue(int delta)

    // Navigate months; capped at 5 years forward from today
    function adjustMonth(delta) {
        let m = viewMonth + delta
        let y = viewYear
        while (m > 11) { m -= 12; y++ }
        while (m < 0)  { m += 12; y-- }
        const maxY = _todayYear + 5
        const maxM = _todayMonth
        if (y > maxY || (y === maxY && m > maxM)) {
            y = maxY; m = maxM
        }
        viewYear = y
        viewMonth = m
    }

    // Fixed height to accommodate the maximum 6-week month; never resizes
    implicitHeight: Math.round(em * 0.5)
        + Math.round(em * 1.4)
        + Math.round(em * 1.0)
        + 6 * Math.round(em * 1.8)
        + Math.round(em * 1.4)

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

        // Month/year header with prev/next buttons
        Item {
            width: parent.width
            height: Math.round(root.em * 1.4)

            readonly property bool prevFocused: root.inZoneMode && root.currentItemIndex === 0
            readonly property bool nextFocused: root.inZoneMode && root.currentItemIndex === root._daysInMonth + 1

            // Prev month button
            Rectangle {
                id: prevBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: Math.round(root.em * 1.4)
                height: Math.round(root.em * 1.4)
                radius: Math.round(root.em * 0.3)
                color: parent.prevFocused
                    ? Qt.rgba(Colors.green.r, Colors.green.g, Colors.green.b, 0.2)
                    : "transparent"
                border.width: parent.prevFocused ? 1 : 0
                border.color: Colors.green

                Text {
                    anchors.centerIn: parent
                    text: "<"
                    color: parent.parent.prevFocused ? Colors.green : Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.adjustMonth(-1)
                }
            }

            // Month/year label
            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                color: root._isCurrentMonth ? Colors.fg : Colors.muted
                font { family: Colors.font; pixelSize: Math.round(root.em * 0.9); bold: true }
            }

            // Next month button
            Rectangle {
                id: nextBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                width: Math.round(root.em * 1.4)
                height: Math.round(root.em * 1.4)
                radius: Math.round(root.em * 0.3)
                color: parent.nextFocused
                    ? Qt.rgba(Colors.green.r, Colors.green.g, Colors.green.b, 0.2)
                    : "transparent"
                border.width: parent.nextFocused ? 1 : 0
                border.color: Colors.green

                Text {
                    anchors.centerIn: parent
                    text: ">"
                    color: parent.parent.nextFocused ? Colors.green : Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.8) }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.adjustMonth(1)
                }
            }
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
                    readonly property bool isToday: isDay && root._isCurrentMonth && dayNum === root._todayDay
                    // Index mapping: prev button = 0, day N = N (dayNum), next button = daysInMonth+1
                    readonly property bool isFocused: root.inZoneMode && isDay
                        && dayNum === root.currentItemIndex

                    width: Math.round(parent.width / 7)
                    height: Math.round(root.em * 1.8)

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(root.em * 1.6)
                        height: width
                        radius: width / 2
                        color: isToday
                            ? Qt.rgba(Colors.blue.r, Colors.blue.g, Colors.blue.b, 0.3)
                            : "transparent"
                        border.width: isToday ? 1 : 0
                        border.color: Colors.blue
                    }

                    Text {
                        anchors.centerIn: parent
                        text: isDay ? dayNum : ""
                        color: isFocused ? Colors.green : isToday ? Colors.blue : Colors.fg
                        font {
                            family: Colors.font
                            pixelSize: Math.round(root.em * 0.8)
                            bold: isToday || isFocused
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
