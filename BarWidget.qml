import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// wartafak.sysmon bar widget: compact CPU/GPU/MEM readout.
// Owns the 2s poller and the 10-minute (300-sample) histories; the popup
// panel (Panel.qml) reads them through `hostWidget`.
BarWidget {
  id: root
  moduleName: "wartafak.sysmon"

  // ---- live values (null = unavailable) ----
  property var cpu: null
  property var cpuTemp: null
  property var gpu: null
  property var gpuTemp: null
  property string gpuVendor: "none"
  property string gpuName: ""
  property string gpuShort: ""
  property string cpuModel: ""
  property var cpuThreads: null
  property var cpuMaxGhz: null
  property var mem: null
  property var memUsedKb: null
  property var memTotalKb: null

  // ---- 10-minute histories (2s x 300) ----
  property var cpuHist: []
  property var cpuTempHist: []
  property var gpuHist: []
  property var gpuTempHist: []
  property var memHist: []

  readonly property var cpuAvg: Model.average(cpuHist)
  readonly property var cpuTempAvg: Model.average(cpuTempHist)
  readonly property var gpuAvg: Model.average(gpuHist)
  readonly property var gpuTempAvg: Model.average(gpuTempHist)
  readonly property var memAvg: Model.average(memHist)
  readonly property int sampleCount: Math.max(cpuHist.length, memHist.length)
  readonly property bool hasGpu: gpuVendor !== "none"

  readonly property string helperPath: (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/wartafak.sysmon/stats.sh"
  readonly property int pollMs: 2000

  function refresh() {
    if (!statsProc.running) {
      statsProc.command = ["bash", helperPath]
      statsProc.running = true
    }
  }

  function applyStats(raw) {
    var s = Model.parseStats(raw)
    root.cpu = s.cpu
    root.cpuTemp = s.cpuTemp
    root.gpu = s.gpu
    root.gpuTemp = s.gpuTemp
    root.gpuVendor = s.gpuVendor
    root.gpuName = s.gpuName
    root.gpuShort = s.gpuShort
    root.cpuModel = s.cpuModel
    root.cpuThreads = s.cpuThreads
    root.cpuMaxGhz = s.cpuMaxGhz
    root.mem = s.mem
    root.memUsedKb = s.memUsedKb
    root.memTotalKb = s.memTotalKb
    // Histories only advance on real samples so a failed poll leaves a
    // gap instead of fabricating a zero.
    root.cpuHist = Model.pushHistory(root.cpuHist, s.cpu, Model.HISTORY_LIMIT)
    root.cpuTempHist = Model.pushHistory(root.cpuTempHist, s.cpuTemp, Model.HISTORY_LIMIT)
    root.gpuHist = Model.pushHistory(root.gpuHist, s.gpu, Model.HISTORY_LIMIT)
    root.gpuTempHist = Model.pushHistory(root.gpuTempHist, s.gpuTemp, Model.HISTORY_LIMIT)
    root.memHist = Model.pushHistory(root.memHist, s.mem, Model.HISTORY_LIMIT)
  }

  function barText() {
    if (root.vertical) return ""
    var parts = []
    parts.push(" " + Model.fmtPct(root.cpu) + " " + Model.fmtTemp(root.cpuTemp))
    if (root.hasGpu)
      parts.push(" " + Model.fmtPct(root.gpu) + " " + Model.fmtTemp(root.gpuTemp))
    parts.push(" " + Model.fmtPct(root.mem))
    return parts.join(" | ")
  }

  function tooltipText() {
    var lines = []
    lines.push("CPU  " + Model.fmtPct(root.cpu) + "  " + Model.fmtTemp(root.cpuTemp)
      + "   (avg " + Model.fmtPct(root.cpuAvg) + "  " + Model.fmtTemp(root.cpuTempAvg) + ")")
    if (root.hasGpu)
      lines.push("GPU  " + Model.fmtPct(root.gpu) + "  " + Model.fmtTemp(root.gpuTemp)
        + "   (avg " + Model.fmtPct(root.gpuAvg) + "  " + Model.fmtTemp(root.gpuTempAvg) + ")")
    lines.push("MEM  " + Model.fmtPct(root.mem) + "   (avg " + Model.fmtPct(root.memAvg) + ")")
    return lines.join("\n")
  }

  // ---- popup panel routing (clock pattern) ----
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Component.onCompleted: refresh()

  Timer {
    interval: root.pollMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStats(text)
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "wartafak.sysmon"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.barText()
    tooltipText: root.tooltipText()
    horizontalMargin: 8.75
    verticalPadding: 8.75
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refresh()
      else root.togglePanel()
    }
  }
}
