import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root
  property var bar: null
  property var shell: null
  property var service: null
  property var manifest: null
  property bool opened: false
  property bool showSettings: false
  property string tokenDraft: ""
  property int minutesDraft: 25
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color bg: bar ? bar.background : Color.background

  function open(payloadJson) { opened = true }
  function close() { opened = false }

  function saveSettings() {
    if (!service) return
    var next={apiToken:tokenDraft,sessionMinutes:minutesDraft,playSound:service.settings.playSound!==false,desktopAnimation:service.settings.desktopAnimation!==false}
    service.settings=next
    if (shell && typeof shell.updateEntryInline === "function") shell.updateEntryInline("david.locu",next)
    if (tokenDraft) { service.refreshTasks(); service.syncTimer() }
    showSettings=false
  }
  onServiceChanged: {
    if (!service) return
    tokenDraft=service.settings.apiToken||""
    minutesDraft=parseInt(service.settings.sessionMinutes,10)||25
  }

  FloatingWindow {
    id: window
    title: "Locu Focus"
    implicitWidth: 440
    implicitHeight: 500
    minimumSize: Qt.size(380, 420)
    maximumSize: Qt.size(440, 500)
    color: root.bg
    visible: root.opened
    onVisibleChanged: if (!visible && root.opened) root.close()

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: root.bg
      border.color: Color.muted
      border.width: 1
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(16)
        spacing: Style.space(10)
      RowLayout {
        Layout.fillWidth:true
        Text { text: root.showSettings ? "Locu settings" : "Locu focus"; color:root.fg; font.family:Style.font.family; font.pixelSize:Style.font.title; font.bold:true }
        Item { Layout.fillWidth:true }
        Button { text:"⚙"; onClicked: { root.showSettings=!root.showSettings; if(root.showSettings && root.service){root.tokenDraft=root.service.settings.apiToken||"";root.minutesDraft=parseInt(root.service.settings.sessionMinutes,10)||25} } }
        Button { text:"×"; onClicked:root.close() }
      }
      ColumnLayout {
        visible:!root.showSettings
        Layout.fillWidth:true
        Layout.fillHeight:true
        Text {
          Layout.fillWidth:true
          horizontalAlignment:Text.AlignHCenter
          text:root.service && (root.service.timerState === "ACTIVE" || root.service.timerState === "PAUSED") ? Math.floor(root.service.remainingSeconds/60).toString().padStart(2,"0")+":"+(root.service.remainingSeconds%60).toString().padStart(2,"0") : "Ready to focus"
          color:root.fg; font.family:"JetBrainsMono Nerd Font"; font.pixelSize:32; font.bold:true
        }
        Text { visible:root.service && root.service.timerState === "PAUSED"; Layout.fillWidth:true; horizontalAlignment:Text.AlignHCenter; text:"Paused — timer frozen"; color:Color.muted }
        Text { Layout.fillWidth:true; horizontalAlignment:Text.AlignHCenter; text:root.service && root.service.activeTask ? root.service.activeTask.name : "Choose a task from Today"; color:Color.muted; elide:Text.ElideRight; textFormat:Text.PlainText }
        Text { visible:root.service && root.service.error!==""; Layout.fillWidth:true; text:root.service ? root.service.error : ""; color:"#ff6b6b"; wrapMode:Text.Wrap; textFormat:Text.PlainText }
        Text { text:"TODAY"; color:Color.muted; font.pixelSize:Style.font.caption; font.bold:true }
        ListView {
          Layout.fillWidth:true; Layout.fillHeight:true; Layout.preferredHeight:Math.min(contentHeight,240); Layout.maximumHeight:240; clip:true; model:root.service ? root.service.tasks : []
          ScrollBar.vertical: ScrollBar {}
          delegate: Button {
            width:ListView.view.width
            text:modelData.name
            onClicked:root.service.start(modelData)
          }
        }
        RowLayout {
          Layout.fillWidth:true
          Button { text:(root.service && (root.service.timerState === "ACTIVE" || root.service.timerState === "PAUSED")) ? "Stop session" : "Start without a task"; onClicked:(root.service.timerState === "ACTIVE" || root.service.timerState === "PAUSED") ? root.service.stop() : root.service.start(null) }
          Button { visible:root.service && root.service.timerState === "ACTIVE"; text:"Pause"; onClicked:root.service.pause() }
          Button { visible:root.service && root.service.timerState === "PAUSED"; text:"Resume"; onClicked:root.service.resume() }
          Button { visible:root.service && root.service.sessionEnded; text:"Keep working"; onClicked:root.service.continueWork() }
          Button { visible:root.service && root.service.sessionEnded; text:"Take a break"; onClicked:root.service.takeBreak() }
          Item { Layout.fillWidth:true }
          Button { text:"Refresh"; onClicked:root.service.refreshTasks() }
          Button { text:"Open webapp"; onClicked:Qt.openUrlExternally("https://web.locu.app/") }
        }
      }
      ColumnLayout {
        visible:root.showSettings
        Layout.fillWidth:true
        Text { text:"API key"; color:root.fg }
        TextField { Layout.fillWidth:true; text:root.tokenDraft; echoMode:TextInput.Password; placeholderText:"Locu Personal Access Token"; onTextChanged:root.tokenDraft=text }
        Text { text:"Session length (minutes)"; color:root.fg }
        SpinBox { from:1; to:180; value:root.minutesDraft; onValueChanged:root.minutesDraft=value }
        CheckBox { text:"Play sound when session ends"; checked:root.service ? root.service.settings.playSound!==false : true; onToggled:if(root.service)root.service.settings.playSound=checked }
        CheckBox { text:"Show desktop animation when session ends"; checked:root.service ? root.service.settings.desktopAnimation!==false : true; onToggled:if(root.service)root.service.settings.desktopAnimation=checked }
        RowLayout { Button { text:"Cancel"; onClicked:root.showSettings=false } Item {Layout.fillWidth:true} Button {text:"Save";onClicked:root.saveSettings()} }
      }
    }
      SequentialAnimation {
        running:root.service && root.service.sessionEnded && root.service.settings.desktopAnimation!==false
        loops:Animation.Infinite
        NumberAnimation { target:window; property:"opacity"; from:1; to:0.65; duration:450 }
        NumberAnimation { target:window; property:"opacity"; from:0.65; to:1; duration:450 }
      }
    }
  }
}
