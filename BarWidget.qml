import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "david.locu"
  property var locuService: null
  readonly property bool inSession: locuService ? (locuService.timerState === "ACTIVE" || locuService.timerState === "PAUSED") : false
  readonly property bool isPaused: locuService ? locuService.timerState === "PAUSED" : false
  readonly property bool isOvertime: locuService ? (locuService.overtime === true || locuService.sessionEnded === true) : false
  readonly property color defaultFg: bar ? bar.barForeground : Color.foreground
  readonly property string timeText: {
    var s = locuService ? locuService.remainingSeconds : 0
    return Math.floor(s/60).toString().padStart(2,"0") + ":" + (s%60).toString().padStart(2,"0")
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onSettingsChanged: if (locuService) locuService.settings = settings
  Timer { interval:250; repeat:true; running:root.bar && root.bar.shell && !locuService; onTriggered: { if (root.bar && root.bar.shell) { var s=root.bar.shell.serviceFor("david.locu"); if (s) { root.locuService=s; s.settings=root.settings } } } }
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    foreground: root.isOvertime ? "#ff9e00" : root.inSession ? "#22c55e" : root.defaultFg
    text: root.inSession ? " " + root.timeText : ""
    tooltipText: root.isOvertime ? "Locu Focus · overtime" : root.isPaused ? "Locu Focus · paused " + root.timeText : root.inSession ? "Locu Focus · " + root.timeText : "Locu Focus"
    fontFamily: "JetBrainsMono Nerd Font"
    onPressed: function(b) {
      if (b === Qt.LeftButton && root.bar && root.bar.shell)
        root.bar.shell.summon("david.locu", "{}")
    }
  }
  SequentialAnimation on opacity {
    running: root.locuService && root.locuService.sessionEnded && root.settings.desktopAnimation !== false
    loops: Animation.Infinite
    NumberAnimation { to:0.35; duration:320 }
    NumberAnimation { to:1; duration:320 }
  }
}
