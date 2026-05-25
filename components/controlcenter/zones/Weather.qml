import QtQuick
import Quickshell.Io
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
    HoverHandler { id: zoneHover }

    color: root.inZoneMode ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08)
         : (root.zoneActive || zoneHover.hovered) ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.04)
         : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    // --- Config ---
    property string weatherLocation: ""
    property string _weatherApiKeyPath: ""
    property string weatherText: ""
    property string _apiKey: ""
    // true once the initial config read finishes (prevents premature error display)
    property bool _configLoaded: false
    // true only when key path is configured but the key file could not be read (transient)
    property bool _keyTransientError: false
    // true when key path is absent from config (permanent - not configured)
    property bool _keyMissingError: false

    property bool _keyError: _keyMissingError || _keyTransientError

    function refresh() {
        root._configLoaded = false
        root._keyTransientError = false
        root._keyMissingError = false
        root._apiKey = ""
        root.weatherText = ""
        root._weatherApiKeyPath = ""
        root.weatherLocation = ""
        weatherConfigProc.running = true
    }

    Component.onCompleted: {
        weatherConfigProc.running = true
    }

    // Retries the key read every 30s when in transient error (e.g. sops not ready yet)
    Timer {
        id: retryTimer
        interval: 30000
        running: root._configLoaded && root._keyTransientError
        repeat: true
        onTriggered: {
            root._keyTransientError = false
            keyReadProc.running = true
        }
    }

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
                if (root._weatherApiKeyPath.length > 0) {
                    keyReadProc.running = true
                } else {
                    root._configLoaded = true
                    root._keyMissingError = true
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root._configLoaded = true
                root._keyMissingError = true
            }
        }
    }

    Process {
        id: keyReadProc
        command: ["sh", "-c", "cat \"" + root._weatherApiKeyPath + "\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const json = JSON.parse(text.trim())
                    root._apiKey = json.weather_api_key ?? ""
                } catch(e) {}
                root._configLoaded = true
                if (root._apiKey.length === 0) root._keyTransientError = true
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root._configLoaded = true
                root._keyTransientError = true
            }
        }
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
        interval: 600000
        running: root._apiKey.length > 0 && root.weatherLocation.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.round(root.em * 0.4)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.weatherText
            color: Colors.fg
            font { family: Colors.font; pixelSize: Math.round(root.em * 1.8) }
            visible: root.weatherText.length > 0 && !root._keyError
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Colors.subtle
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.75) }
            text: root._keyMissingError ? "weather key not configured" : "weather key unavailable"
            visible: root._configLoaded && root._keyError
            opacity: 0.6
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Colors.subtle
            font { family: Colors.font; pixelSize: Math.round(root.em * 0.6) }
            text: "click to retry"
            visible: root._configLoaded && root._keyError
            opacity: 0.4
        }
    }
}
