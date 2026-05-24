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
            body: notif.body ?? ""
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
