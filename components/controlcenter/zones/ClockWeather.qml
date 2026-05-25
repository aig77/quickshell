import QtQuick
import Quickshell.Io
import "../../"

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
    HoverHandler { id: zoneHover }

    color: root.inZoneMode ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08)
         : (root.zoneActive || zoneHover.hovered) ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.04)
         : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    // --- Config ---
    property string weatherLocation: ""
    property string _weatherApiKeyPath: ""

    // --- Weather state ---
    property string weatherText: ""
    property string _apiKey: ""
    property bool _keyError: false

    Component.onCompleted: {
        weatherConfigProc.running = true
    }

    // Read weather.json via shell so $HOME expands correctly
    Process {
        id: weatherConfigProc
        command: ["sh", "-c", "cat \"$HOME/.cache/bebop/weather.json\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const cfg = JSON.parse(text.trim())
                    const loc = cfg?.location ?? ""
                    const keyPath = cfg?.weatherApiKeyPath ?? ""
                    if (loc.length > 0) root.weatherLocation = loc
                    if (keyPath.length > 0) root._weatherApiKeyPath = keyPath
                } catch(e) {}
                if (root._weatherApiKeyPath.length > 0)
                    keyReadProc.running = true
                else
                    root._keyError = true
            }
        }
        onExited: (code) => { if (code !== 0) root._keyError = true }
    }

    // Read API key from sops template path
    Process {
        id: keyReadProc
        command: ["sh", "-c", "cat \"" + root._weatherApiKeyPath + "\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const json = JSON.parse(text.trim())
                    root._apiKey = json.weather_api_key ?? ""
                } catch(e) {}
                if (root._apiKey.length === 0) root._keyError = true
            }
        }
        onExited: (code) => { if (code !== 0) root._keyError = true }
    }

    function conditionEmoji(code, isDay) {
        if (code === 1000) return isDay ? "☀️" : "🌙"
        if (code === 1003) return isDay ? "⛅" : "☁️"
        if (code === 1006 || code === 1009) return "☁️"
        if (code === 1030 || code === 1135 || code === 1147) return "🌫️"
        if (code === 1087 || (code >= 1273 && code <= 1282)) return "⛈️"
        if (code === 1114 || code === 1117 || (code >= 1210 && code <= 1225) || code === 1255 || code === 1258 || code === 1279 || code === 1282) return "❄️"
        if ((code >= 1204 && code <= 1207) || (code >= 1249 && code <= 1252)) return "🌨️"
        if (code >= 1150 && code <= 1201) return "🌧️"
        if (code >= 1240 && code <= 1246) return "🌦️"
        return "🌡️"
    }

    // Fetch weather from weatherapi.com
    Process {
        id: weatherProc
        property string _url: "http://api.weatherapi.com/v1/current.json?key=" + root._apiKey + "&q=" + root.weatherLocation + "&aqi=no"
        command: ["curl", "-s", "--max-time", "10", weatherProc._url]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    const temp = data?.current?.temp_c
                    const code = data?.current?.condition?.code ?? 0
                    const isDay = (data?.current?.is_day ?? 1) === 1
                    if (temp !== undefined && code > 0)
                        root.weatherText = root.conditionEmoji(code, isDay) + " " + Math.round(temp) + "°C"
                    else
                        root.weatherText = ""
                } catch(e) {
                    root.weatherText = ""
                }
            }
        }
    }

    Timer {
        interval: 600000  // 10 min
        running: root._apiKey.length > 0 && root.weatherLocation.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    // --- Layout: clock+date on left, weather on right ---
    Item {
        anchors {
            fill: parent
            leftMargin: Math.round(root.em * 1.5)
            rightMargin: Math.round(root.em * 1.5)
        }

        Column {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: Math.round(root.em * 0.2)

            Text {
                id: clockText
                color: Colors.fg
                font { family: Colors.font; pixelSize: Math.round(root.em * 3) }
                text: Qt.formatDateTime(new Date(), "HH:mm")
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
                }
            }

            Text {
                color: Colors.muted
                font { family: Colors.font; pixelSize: Math.round(root.em * 0.9) }
                text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
            }
        }

        Column {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Math.round(root.em * 0.3)

            Text {
                anchors.right: parent.right
                color: Colors.muted
                font { family: Colors.font; pixelSize: Math.round(root.em * 1.8) }
                text: root.weatherText
                visible: root.weatherText.length > 0 && !root._keyError
            }

            Text {
                anchors.right: parent.right
                color: Colors.subtle
                font { family: Colors.font; pixelSize: Math.round(root.em * 0.75) }
                text: "no weather api key"
                visible: root._keyError
                opacity: 0.6
            }
        }
    }
}
