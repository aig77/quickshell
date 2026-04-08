//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import Quickshell
import "./"
import "./overview/modules/overview/"
import "./overview/services/"
import "./overview/common/"
import "./overview/common/functions/"
import "./overview/common/widgets/"
import "./notifications/"

ShellRoot {
  Bar {}
  Dock {}
  Overview {}
  NotificationStack {}
}
