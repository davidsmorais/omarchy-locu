import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  readonly property string pluginId: "david.locu"
  readonly property string baseUrl: "https://api.locu.app/api/v1"
  property var shell: null
  property var settings: ({apiToken:"", sessionMinutes:25, playSound:true, desktopAnimation:true})
  property var tasks: []
  property var activeTask: null
  property string timerState: "IDLE"
  property double endAt: 0
  property int remainingSeconds: 0
  property string error: ""
  property bool loading: false
  property bool sessionEnded: false
  property bool overtime: false
  property var endedTask: null
  property string pendingAction: ""

  function urlQuote(s) { return '"' + String(s).replace(/\\/g,"\\\\").replace(/"/g,'\\"').replace(/\n/g,"\\n") + '"' }
  function api(method, path, body, callback) {
    var conf = "url = " + urlQuote(baseUrl + path) + "\nrequest = " + urlQuote(method) +
      "\nheader = " + urlQuote("Authorization: Bearer " + settings.apiToken) +
      "\nheader = \"Content-Type: application/json\"\nwrite-out = \"\\n__HTTP__:%{http_code}\"\n"
    if (body !== undefined && body !== null) conf += "data-binary = " + urlQuote(JSON.stringify(body)) + "\n"
    var p = requestComponent.createObject(root, {config:conf, callback:callback})
    p.running = true
  }
  function refreshTasks() {
    if (!settings.apiToken) return
    loading = true
    api("GET", "/tasks/sections?section=today", null, function(ok,data,msg) {
      loading = false
      if (!ok) { error = msg; return }
      error = ""
      var rows = data && data.today ? data.today : []
      var out = []
      for (var i=0; i<rows.length; i++) {
        var t = rows[i].task || {}
        if (!t.done && rows[i].section === "today") out.push({id:rows[i].taskId || t.id, name:t.name || "Untitled task"})
      }
      tasks = out
    })
  }
  function syncTimer() {
    if (!settings.apiToken) return
    api("GET", "/timer", null, function(ok,data,msg) {
      if (!ok) { error = msg; return }
      timerState = data.state || "IDLE"
      if (timerState === "ACTIVE" || timerState === "PAUSED") {
        overtime = false
        activeTask = null
        for (var i=0;i<tasks.length;i++) if (tasks[i].id === data.currentTaskId) activeTask = tasks[i]
        if (timerState === "ACTIVE" || !endAt) {
          var duration = Number(data.duration || 0)
          var start = new Date(data.startedAt || 0).getTime()
          endAt = start + duration*1000
          remainingSeconds = Math.max(0, Math.ceil((endAt-Date.now())/1000))
        }
      } else { endAt=0; remainingSeconds=0; activeTask=null }
    })
  }
  function start(task) {
    if (!settings.apiToken) { error="Add your Locu API key in plugin settings"; return }
    activeTask = task || null
    var minutes = Math.max(1, Math.min(180, parseInt(settings.sessionMinutes,10) || 25))
    var payload = {duration:minutes*60}
    if (activeTask) payload.taskId = activeTask.id
    api("POST", "/timer/start", payload, function(ok,data,msg) {
      if (!ok) { error=msg; return }
      sessionEnded=false
      overtime=false
      timerState=data.state || "ACTIVE"
      endAt=Date.now()+minutes*60000
      remainingSeconds=minutes*60
    })
  }
  function pause() {
    if (timerState !== "ACTIVE") return
    api("POST", "/timer/pause", {}, function(ok,data,msg) {
      if (!ok) { error=msg; return }
      timerState=data.state || "PAUSED"
    })
  }
  function resume() {
    if (timerState !== "PAUSED") return
    api("POST", "/timer/continue", {}, function(ok,data,msg) {
      if (!ok) { error=msg; return }
      timerState=data.state || "ACTIVE"
      endAt=Date.now()+Math.max(0,remainingSeconds)*1000
    })
  }
  function stop() {
    api("POST", "/timer/stop", {}, function(ok,data,msg) {
      if (!ok) error=msg
      timerState="IDLE"; endAt=0; remainingSeconds=0; activeTask=null
    })
  }
  function completeSession() {
    if (sessionEnded) return
    sessionEnded=true
    overtime=true
    completionReset.start()
    endedTask=activeTask
    stop()
    if (shell) shell.summon(pluginId, "{}")
    if (settings.playSound) Quickshell.execDetached(["bash","-lc","canberra-gtk-play -i complete >/dev/null 2>&1 || paplay /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1 || true"])
    actionNotification.command=["notify-send","--wait","-a","Locu Focus","Session complete",endedTask ? "Finished: " + endedTask.name : "Your focus session is complete.","--action=continue=Keep working","--action=break=Take a break"]
    actionNotification.running=true
  }
  function tick() {
    if (timerState !== "ACTIVE" || !endAt) return
    remainingSeconds=Math.max(0,Math.ceil((endAt-Date.now())/1000))
    if (!remainingSeconds) completeSession()
  }
  function continueWork() { sessionEnded=false; overtime=false; start(endedTask) }
  function takeBreak() { sessionEnded=false; overtime=false }

  Timer { interval:1000; repeat:true; running:true; onTriggered:root.tick() }
  Timer { interval:30000; repeat:true; running:!!root.settings.apiToken; triggeredOnStart:true; onTriggered:{root.refreshTasks();root.syncTimer()} }
  Timer { id:completionReset; interval:12000; repeat:false; onTriggered:root.sessionEnded=false }
  Component {
    id: requestComponent
    Process {
      property string config: ""
      property var callback: null
      stdinEnabled:true
      command:["curl","--silent","--show-error","--proto","=https","--max-redirs","0","--connect-timeout","8","--max-time","20","--config","-"]
      stdout:StdioCollector { id: output }
      stderr:StdioCollector { id: errors }
      onStarted:{ write(config); config=""; stdinEnabled=false }
      onExited:function(code) {
        var raw=output.text || "", marker="\n__HTTP__:", i=raw.lastIndexOf(marker), status=i<0?0:parseInt(raw.slice(i+marker.length),10), body=i<0?raw:raw.slice(0,i), data=null, cb=callback
        try { data=body ? JSON.parse(body) : null } catch(e) {}
        if (status>=200 && status<300) cb(true,data,"")
        else cb(false,data,(data && (data.message || data.error)) || (status ? "Locu API error " + status : "Could not reach Locu API"))
        destroy()
      }
    }
  }
  Process {
    id: actionNotification
    command: []
    stdout: StdioCollector { id: actionOutput }
    onExited: function(code) {
      var action=String(actionOutput.text || "").trim()
      if (action === "continue") root.continueWork()
      else if (action === "break") root.takeBreak()
    }
  }
}
