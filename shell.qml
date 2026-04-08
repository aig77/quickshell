//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import Quickshell
import "./components/"
import "./components/overview/modules/overview/"
import "./components/overview/services/"
import "./components/overview/common/"

ShellRoot {
  Bar {}
  Dock {}
  Overview {}
  NotificationStack {}
}
