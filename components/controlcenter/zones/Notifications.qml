pragma ComponentBehavior: Bound

import QtQuick
import "../../"
import "../"

Rectangle {
    id: root

    property real em: 16
    property bool zoneActive: false
    property bool inZoneMode: false
    property int currentItemIndex: 0
    property int selectableCount: CCNotifModel.items.count

    signal activated(int index)
    signal adjustValue(int delta)

    // Match Calendar height so both sides of row 1 are equal
    implicitHeight: calHeight > 0 ? calHeight : Math.round(em * 12)
    property real calHeight: 0

    color: "transparent"
    border.width: root.zoneActive ? 2 : 0
    border.color: root.inZoneMode ? Colors.green : root.zoneActive ? Colors.blue : "transparent"

    // Empty state
    Text {
        anchors.centerIn: parent
        text: "No notifications"
        color: Colors.muted
        font { family: Colors.font; pixelSize: Math.round(root.em * 0.85) }
        visible: CCNotifModel.items.count === 0
    }

    ListView {
        id: listView
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Math.round(root.em * 0.6)
        }
        height: Math.min(contentHeight, parent.height - Math.round(root.em * 1.2))
        model: CCNotifModel.items
        clip: true
        currentIndex: root.inZoneMode ? root.currentItemIndex : -1
        spacing: Math.round(root.em * 0.4)

        delegate: Rectangle {
            id: notifRow
            required property var model
            required property int index

            width: listView.width
            height: notifCol.implicitHeight + Math.round(root.em * 0.8)
            radius: Math.round(root.em * 0.4)

            color: notifRow.index === listView.currentIndex
                ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 1)
                : "transparent"

            border.width: notifRow.index === listView.currentIndex ? 1 : 0
            border.color: Colors.green

            Column {
                id: notifCol
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: parent.right
                    leftMargin: Math.round(root.em * 0.6)
                    rightMargin: Math.round(root.em * 0.6)
                }
                spacing: Math.round(root.em * 0.15)

                Text {
                    width: parent.width
                    text: notifRow.model.appName
                    color: Colors.muted
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.7) }
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: notifRow.model.summary
                    color: Colors.fg
                    font { family: Colors.font; pixelSize: Math.round(root.em * 0.85) }
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: if (root.inZoneMode) root.currentItemIndex = notifRow.index
                onClicked: {
                    const uid = notifRow.model.uid
                    CCNotifModel.refs[uid]?.dismiss()
                    CCNotifModel.removeNotif(uid)
                }
            }
        }
    }
}
