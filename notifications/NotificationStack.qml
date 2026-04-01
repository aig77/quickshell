import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import "../"

Scope {
    id: root

    property int _uidCounter: 0
    property var _notifRefs: ({})

    ListModel {
        id: activeItems
    }

    NotificationServer {
        keepOnReload: true
        onNotification: (notif) => {
            notif.tracked = true
            var uid = root._uidCounter++
            root._notifRefs[uid] = notif
            activeItems.insert(0, { uid: uid, type: "notif" })
        }
    }

    function removeItem(uid) {
        for (var i = 0; i < activeItems.count; i++) {
            if (activeItems.get(i).uid === uid) {
                activeItems.remove(i, 1)
                break
            }
        }
        delete root._notifRefs[uid]
    }

    PanelWindow {
        id: win
        anchors.top: true
        anchors.right: true
        implicitWidth: 396
        implicitHeight: 66 + notifColumn.implicitHeight + (notifColumn.implicitHeight > 0 ? 8 : 0)
        color: "transparent"
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

        // MPRIS player watchers — inside PanelWindow for proper visual parenting
        Repeater {
            model: Mpris.players
            delegate: Item {
                width: 0; height: 0; visible: false
                required property var modelData
                Component.onCompleted: {
                    modelData.trackTitleChanged.connect(function() {
                        if (modelData.trackTitle.length > 0) {
                            Qt.callLater(function() {
                                var uid = root._uidCounter++
                                activeItems.insert(0, {
                                    uid: uid,
                                    type: "mpris",
                                    title: modelData.trackTitle,
                                    artist: modelData.trackArtist,
                                    album: modelData.trackAlbum,
                                    artUrl: modelData.trackArtUrl
                                })
                            })
                        }
                    })
                }
            }
        }

        Column {
            id: notifColumn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 30
            anchors.rightMargin: 30
            spacing: 8

            Repeater {
                model: activeItems
                delegate: Loader {
                    required property var model

                    sourceComponent: model.type === "mpris" ? mprisComp : notifComp

                    onLoaded: {
                        var uid = model.uid
                        if (model.type === "mpris") {
                            item.title = model.title
                            item.artist = model.artist
                            item.album = model.album
                            item.artUrl = model.artUrl
                        } else {
                            item.notif = root._notifRefs[uid]
                            item.startAutoTimer()
                        }
                        item.dismissed.connect(() => root.removeItem(uid))
                    }
                }
            }
        }
    }

    Component {
        id: notifComp
        NotificationItem {}
    }

    Component {
        id: mprisComp
        MprisNotificationItem {}
    }
}
