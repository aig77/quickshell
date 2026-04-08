pragma Singleton // makes this a global, importable-once object across all QML files
import QtQuick

QtObject {
  // Catppuccin Mocha — fallback when ~/.cache/stylix/colors.json is absent
  readonly property var _catppuccin: ({
    base00: "#1e1e2e", base01: "#181825", base02: "#313244",
    base03: "#45475a", base04: "#585b70", base05: "#cdd6f4",
    base08: "#f38ba8", base09: "#fab387", base0A: "#f9e2af",
    base0B: "#a6e3a1", base0C: "#94e2d5", base0D: "#89b4fa",
    base0E: "#cba4f7", font: "JetBrainsMono Nerd Font"
  })

  // _p is the active palette — starts as Catppuccin, replaced at runtime if cache exists
  property var _p: _catppuccin

  // Semantic color aliases — use these in shell.qml instead of hex values or base0X names
  property color bg:     _p.base00
  property color mantle: _p.base01
  property color surface:_p.base02
  property color muted:  _p.base03
  property color subtle: _p.base04
  property color fg:     _p.base05
  property color red:    _p.base08
  property color orange: _p.base09
  property color yellow: _p.base0A
  property color green:  _p.base0B
  property color cyan:   _p.base0C
  property color blue:   _p.base0D
  property color purple: _p.base0E
  property string font:  _p.font ?? "JetBrainsMono Nerd Font"

  // On startup: try to load Stylix-generated colors from cache.
  // Synchronous XHR (false = sync) so colors are ready before any component renders.
  // Silently falls back to Catppuccin if the file is missing or malformed.
  Component.onCompleted: {
    try {
      const xhr = new XMLHttpRequest()
      xhr.open("GET", "file:///home/arturo/.cache/stylix/colors.json", false)
      xhr.send()
      if (xhr.responseText.length > 0)
        _p = JSON.parse(xhr.responseText)
    } catch(e) {}
  }
}
