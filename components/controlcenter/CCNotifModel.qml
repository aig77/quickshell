pragma Singleton
import QtQuick

QtObject {
    property ListModel items: ListModel {}
    property var refs: ({})

    function addNotif(uid, notif) {
        refs[uid] = notif
        items.insert(0, {
            uid: uid,
            summary: notif.summary ?? "",
            appName: notif.appName ?? "",
            appIcon: notif.appIcon ?? "",
            body: notif.body ?? "",
            urgency: notif.urgency ?? 1,
            time: Qt.formatTime(new Date(), "HH:mm")
        })
    }

    function removeNotif(uid) {
        for (let i = 0; i < items.count; i++) {
            if (items.get(i).uid === uid) {
                items.remove(i)
                break
            }
        }
        delete refs[uid]
    }
}
