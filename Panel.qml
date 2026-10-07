import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// wartafak.sysmon popup: current values + 10-minute averages + line graphs.
// Live data and histories live on the host BarWidget (hostWidget); this
// panel only renders them.
Panel {
  id: root
  moduleName: "wartafak.sysmon"
  ipcTarget: "wartafak.sysmon"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function windowTitle() {
    var n = hostWidget ? hostWidget.sampleCount : 0
    if (!n) return "COLLECTING SAMPLES…"
    var secs = Math.min(n * 2, 600)
    var mm = Math.floor(secs / 60), ss = secs % 60
    return "LAST " + mm + "M " + (ss < 10 ? "0" + ss : ss) + "S · 2S SAMPLES"
  }

  function cpuHeader() {
    if (!hostWidget) return "CPU"
    return Model.cpuTitle({ cpuModel: hostWidget.cpuModel, cpuThreads: hostWidget.cpuThreads, cpuMaxGhz: hostWidget.cpuMaxGhz })
  }

  function gpuHeader() {
    if (!hostWidget) return "GPU"
    return Model.gpuTitle({ gpuShort: hostWidget.gpuShort })
  }

  function memHeader() {
    if (!hostWidget) return "MEMORY"
    return Model.memTitle({ memTotalKb: hostWidget.memTotalKb })
  }

  // ---- process table state (raw list lives on hostWidget) ----
  property string procSortKey: "cpu"
  property int procSortDir: -1
  readonly property int procRowCap: 25
  readonly property int procNumW: Style.space(52)
  readonly property int procMemW: Style.space(108)
  readonly property int procPidW: Style.space(58)
  readonly property int procBtnW: Style.space(46)
  readonly property var sortedProcs: Model.sortProcesses(
    hostWidget ? hostWidget.processes : [], procSortKey, procSortDir
  ).slice(0, procRowCap)
  // Last pid copied to the clipboard; the cell flashes ✓ until cleared.
  property int copiedPid: -1

  function procHeader() {
    var n = hostWidget ? hostWidget.processCount : 0
    return "PROCESSES · " + n
  }

  function procSortLabel(key, title) {
    var arrow = procSortKey === key ? (procSortDir === 1 ? " ▲" : " ▼") : ""
    return title + arrow
  }

  function toggleProcSort(key) {
    if (procSortKey === key) procSortDir = -procSortDir
    else {
      procSortKey = key
      procSortDir = key === "comm" || key === "pid" ? 1 : -1
    }
  }

  function copyPid(pid) {
    if (!hostWidget) return
    hostWidget.copyPid(pid)
    root.copiedPid = pid
    copyFlash.restart()
  }

  // Browser-style jump anchor: the table lives at the bottom of the same
  // scroll view, so the top button just moves the scrollbar there. position
  // is a 0..1 fraction over the FULL contentHeight (contentY = position x
  // contentHeight, visibleArea semantics) and writable (same path as
  // dragging the thumb). Re-asserted once via procJumpSettle: delegate
  // creation spreads over frames, so contentHeight can grow right after
  // the click and leave the first jump short.
  function scrollToProcesses() {
    if (!processesSection) return
    jumpToProcesses()
    procJumpSettle.restart()
  }

  function jumpToProcesses() {
    var total = Math.max(1, scrollArea.contentHeight)
    var target = (processesSection.y - Style.space(8)) / total
    scrollArea.ScrollBar.vertical.position = Math.max(0, Math.min(1, target))
  }

  Timer {
    id: copyFlash
    interval: 1200
    onTriggered: root.copiedPid = -1
  }

  Timer {
    id: procJumpSettle
    interval: 150
    onTriggered: root.jumpToProcesses()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(bodyColumn.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: bodyColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: bodyColumn
          width: scrollArea.availableWidth
          spacing: Style.space(12)

          PanelHero {
            title: "System Monitor"
            meta: root.windowTitle()
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          // ---------- Top summary: current usage rings + temp ----------
          // Gauges split the full width evenly (hidden GPU card takes no
          // space, so 2 or 3 gauges always spread edge to edge).
          Item {
            width: parent.width
            implicitHeight: summaryRow.implicitHeight
            height: summaryRow.height

            RowLayout {
              id: summaryRow
              width: parent.width
              spacing: Style.space(8)

              SummaryCard {
                title: "CPU"
                Layout.fillWidth: true
                usage: hostWidget ? hostWidget.cpu : null
                subText: hostWidget ? Model.fmtTemp(hostWidget.cpuTemp) : "--"
                subColor: hostWidget ? hostWidget.themeTemp : "#e0af68"
                ringColor: Color.accent
              }

              SummaryCard {
                visible: hostWidget ? hostWidget.hasGpu : false
                title: "GPU"
                Layout.fillWidth: true
                usage: hostWidget ? hostWidget.gpu : null
                subText: hostWidget ? Model.fmtTemp(hostWidget.gpuTemp) : "--"
                subColor: hostWidget ? hostWidget.themeTemp : "#e0af68"
                ringColor: Color.accent
              }

              SummaryCard {
                title: "MEMORY"
                Layout.fillWidth: true
                usage: hostWidget ? hostWidget.mem : null
                // show GB detail under the ring when available; NOW info only
                detailText: hostWidget ? Model.fmtMemDetail(hostWidget.memUsedKb, hostWidget.memTotalKb) : ""
                ringColor: hostWidget ? hostWidget.themeGreen : "#9ece6a"
              }
            }
          }

          // Jump anchor to the process table at the bottom. Doubles as a
          // live process count.
          Item {
            width: parent.width
            implicitHeight: procJump.implicitHeight
            height: procJump.height

            Button {
              id: procJump
              anchors.horizontalCenter: parent.horizontalCenter
              text: "↓ PROCESSES · " + (hostWidget ? hostWidget.processCount : 0)
              fontFamily: root.contentFontFamily
              bordered: true
              background: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
              onClicked: root.scrollToProcesses()
            }
          }

          // ---------- CPU ----------
          PanelSeparator { foreground: root.contentForeground }

          PanelSectionHeader {
            text: root.cpuHeader()
            width: parent.width
            elide: Text.ElideRight
            foreground: hostWidget ? hostWidget.themePurple : "#ad8ee6"
            fontFamily: root.contentFontFamily
          }

          StatRow {
            label: "USAGE"
            now: hostWidget ? Model.fmtPct(hostWidget.cpu) : "--"
            avg: hostWidget ? Model.fmtPct(hostWidget.cpuAvg) : "--"
          }
          HistoryGraph {
            history: hostWidget ? hostWidget.cpuHist : []
            lineColor: Color.accent
            unit: "%"
            minVal: 0
            maxVal: 100
          }

          StatRow {
            label: "TEMP"
            now: hostWidget ? Model.fmtTemp(hostWidget.cpuTemp) : "--"
            avg: hostWidget ? Model.fmtTemp(hostWidget.cpuTempAvg) : "--"
          }
          HistoryGraph {
            history: hostWidget ? hostWidget.cpuTempHist : []
            lineColor: hostWidget ? hostWidget.themeTemp : "#e0af68"
            unit: "°"
            minVal: 0
            maxVal: 120
          }

          // ---------- GPU ----------
          PanelSeparator {
            visible: hostWidget ? hostWidget.hasGpu : false
            foreground: root.contentForeground
          }

          PanelSectionHeader {
            visible: hostWidget ? hostWidget.hasGpu : false
            text: root.gpuHeader()
            width: parent.width
            elide: Text.ElideRight
            foreground: hostWidget ? hostWidget.themePurple : "#ad8ee6"
            fontFamily: root.contentFontFamily
          }

          StatRow {
            visible: hostWidget ? hostWidget.hasGpu : false
            label: "USAGE"
            now: hostWidget ? Model.fmtPct(hostWidget.gpu) : "--"
            avg: hostWidget ? Model.fmtPct(hostWidget.gpuAvg) : "--"
          }
          HistoryGraph {
            visible: hostWidget ? hostWidget.hasGpu : false
            history: hostWidget ? hostWidget.gpuHist : []
            lineColor: Color.accent
            unit: "%"
            minVal: 0
            maxVal: 100
          }

          StatRow {
            visible: hostWidget ? hostWidget.hasGpu : false
            label: "TEMP"
            now: hostWidget ? Model.fmtTemp(hostWidget.gpuTemp) : "--"
            avg: hostWidget ? Model.fmtTemp(hostWidget.gpuTempAvg) : "--"
          }
          HistoryGraph {
            visible: hostWidget ? hostWidget.hasGpu : false
            history: hostWidget ? hostWidget.gpuTempHist : []
            lineColor: hostWidget ? hostWidget.themeTemp : "#e0af68"
            unit: "°"
            minVal: 0
            maxVal: 120
          }

          // ---------- Memory ----------
          PanelSeparator { foreground: root.contentForeground }

          PanelSectionHeader {
            text: root.memHeader()
            width: parent.width
            elide: Text.ElideRight
            foreground: hostWidget ? hostWidget.themePurple : "#ad8ee6"
            fontFamily: root.contentFontFamily
          }

          StatRow {
            label: "USAGE"
            now: hostWidget ? Model.fmtPct(hostWidget.mem) : "--"
            avg: hostWidget ? Model.fmtPct(hostWidget.memAvg) : "--"
            extra: hostWidget ? Model.fmtMemDetail(hostWidget.memUsedKb, hostWidget.memTotalKb) : ""
          }
          HistoryGraph {
            history: hostWidget ? hostWidget.memHist : []
            lineColor: hostWidget ? hostWidget.themeGreen : "#9ece6a"
            unit: "%"
            minVal: 0
            maxVal: 100
          }

          // ---------- Processes ----------
          PanelSeparator { foreground: root.contentForeground }

          Item {
            id: processesSection
            width: parent.width
            implicitHeight: procCol.implicitHeight
            height: procCol.height

            Column {
              id: procCol
              width: parent.width
              spacing: Style.space(6)

              Item {
                width: parent.width
                implicitHeight: Math.max(procTitle.implicitHeight, copyHint.implicitHeight)
                height: implicitHeight

                PanelSectionHeader {
                  id: procTitle
                  text: root.procHeader()
                  width: parent.width - copyHint.implicitWidth - Style.space(8)
                  elide: Text.ElideRight
                  foreground: hostWidget ? hostWidget.themePurple : "#ad8ee6"
                  fontFamily: root.contentFontFamily
                }

                Text {
                  id: copyHint
                  textFormat: Text.PlainText
                  text: "CLICK PID TO COPY"
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Sortable column headers; column geometry mirrors ProcRow.
              Item {
                width: parent.width
                height: Math.max(nameHead.implicitHeight, cpuHead.implicitHeight)

                Text {
                  id: nameHead
                  textFormat: Text.PlainText
                  text: root.procSortLabel("comm", "PROCESS")
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.left: parent.left
                  anchors.right: pidHead.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleProcSort("comm")
                  }
                }

                Text {
                  id: killHead
                  textFormat: Text.PlainText
                  text: ""
                  width: root.procBtnW * 2
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  id: memHead
                  textFormat: Text.PlainText
                  text: root.procSortLabel("mem", "MEM")
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  horizontalAlignment: Text.AlignRight
                  width: root.procMemW
                  anchors.right: killHead.left
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleProcSort("mem")
                  }
                }

                Text {
                  id: cpuHead
                  textFormat: Text.PlainText
                  text: root.procSortLabel("cpu", "CPU")
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  horizontalAlignment: Text.AlignRight
                  width: root.procNumW
                  anchors.right: memHead.left
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleProcSort("cpu")
                  }
                }

                Text {
                  id: pidHead
                  textFormat: Text.PlainText
                  text: root.procSortLabel("pid", "PID")
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  horizontalAlignment: Text.AlignRight
                  width: root.procPidW
                  anchors.right: cpuHead.left
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleProcSort("pid")
                  }
                }
              }

              Repeater {
                model: root.sortedProcs
                delegate: ProcRow {}
              }

              Text {
                visible: !root.sortedProcs || root.sortedProcs.length === 0
                textFormat: Text.PlainText
                text: "sampling…"
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                visible: hostWidget ? hostWidget.processCount > root.procRowCap : false
                textFormat: Text.PlainText
                text: "SHOWING " + root.procRowCap + " OF " + (hostWidget ? hostWidget.processCount : 0)
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }
          }

          Item {
            width: parent.width
            height: Style.space(4)
          }
        }
      }
    }
  }

  // Top summary card: title above a usage ring, NOW values inside.
  // Ring fill = usage %; temp (CPU/GPU) or GB detail (memory) sits inside
  // as text since temp can't fill the same ring.
  component SummaryCard: Column {
    id: card
    required property string title
    required property var usage
    property string subText: ""
    property string detailText: ""
    property color subColor: Qt.darker(root.contentForeground, 1.4)
    required property color ringColor

    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      text: card.title
      color: Qt.darker(root.contentForeground, 1.4)
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Item {
      id: ringWrap
      width: Style.space(104)
      height: Style.space(104)
      anchors.horizontalCenter: parent.horizontalCenter

      Canvas {
        id: ringCanvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
          var ctx = getContext("2d")
          var w = width, h = height
          ctx.clearRect(0, 0, w, h)
          var cx = w / 2, cy = h / 2
          var radius = Math.min(w, h) / 2 - 6
          var lw = 7
          ctx.lineWidth = lw
          // track
          ctx.strokeStyle = Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.16)
          ctx.beginPath()
          ctx.arc(cx, cy, radius, 0, Math.PI * 2)
          ctx.stroke()
          // value arc
          var v = card.usage
          var frac = (typeof v === "number" && isFinite(v)) ? Math.max(0, Math.min(100, v)) / 100 : 0
          if (frac > 0) {
            ctx.strokeStyle = card.ringColor
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(cx, cy, radius, -Math.PI / 2, -Math.PI / 2 + frac * Math.PI * 2)
            ctx.stroke()
          }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
          target: card
          function onUsageChanged() { ringCanvas.requestPaint() }
          function onRingColorChanged() { ringCanvas.requestPaint() }
        }
        Connections {
          target: root
          function onContentForegroundChanged() { ringCanvas.requestPaint() }
        }
      }

      Column {
        anchors.centerIn: parent
        spacing: 0
        width: parent.width - Style.space(24)

        Text {
          textFormat: Text.PlainText
          text: Model.fmtPct(card.usage)
          color: card.ringColor
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          anchors.horizontalCenter: parent.horizontalCenter
          elide: Text.ElideRight
          width: parent.width
        }

        Text {
          // CPU/GPU: temp; Memory: GB detail (empty when unknown)
          textFormat: Text.PlainText
          text: card.detailText !== "" ? card.detailText : card.subText
          color: card.detailText !== "" ? Qt.darker(root.contentForeground, 1.4) : card.subColor
          font.family: root.contentFontFamily
          font.pixelSize: card.detailText !== "" ? Style.font.caption : Style.font.body
          font.bold: card.detailText === ""
          horizontalAlignment: Text.AlignHCenter
          anchors.horizontalCenter: parent.horizontalCenter
          elide: Text.ElideRight
          width: parent.width
        }
      }
    }
  }

  // "LABEL   NOW x   AVG 10M y" row with optional trailing detail.
  component StatRow: Item {
    id: statRow
    required property string label
    required property string now
    required property string avg
    property string extra: ""

    width: parent ? parent.width : 0
    implicitHeight: Math.max(nowText.implicitHeight, avgText.implicitHeight)

    Text {
      id: labelText
      textFormat: Text.PlainText
      text: statRow.label
      color: Qt.darker(root.contentForeground, 1.4)
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: nowText
      textFormat: Text.PlainText
      text: "NOW " + statRow.now + (statRow.extra !== "" ? "  ·  " + statRow.extra : "")
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.horizontalCenterOffset: -Style.space(40)
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
    }

    Text {
      id: avgText
      textFormat: Text.PlainText
      text: "AVG 10M " + statRow.avg
      color: Qt.darker(root.contentForeground, 1.4)
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // One process row: "name · pid" plus CPU/MEM and TERM/KILL actions.
  // Right-hand column geometry mirrors the ProcHeader above.
  // NOTE: the row object arrives as required modelData (auto-filled by the
  // Repeater). Do NOT pass it from the delegate site (`proc: modelData`
  // fails: bindings on an inline `component` instance resolve in the
  // definition scope, where modelData does not exist).
  component ProcRow: Item {
    id: procRow
    required property var modelData
    readonly property var proc: modelData

    width: parent ? parent.width : 0
    implicitHeight: Math.max(nameText.implicitHeight, termBtn.height, killBtn.height) + Style.space(4)
    height: implicitHeight

    Text {
      id: nameText
      textFormat: Text.PlainText
      text: String(procRow.proc.comm || "")
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      anchors.left: parent.left
      anchors.right: pidText.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
    }

    // Click copies the pid; flashes ✓ until the timer clears it.
    Text {
      id: pidText
      textFormat: Text.PlainText
      text: root.copiedPid === procRow.proc.pid ? "✓" : String(procRow.proc.pid)
      color: root.copiedPid === procRow.proc.pid ? Color.accent : Qt.darker(root.contentForeground, 1.4)
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignRight
      width: root.procPidW
      anchors.right: cpuText.left
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.copyPid(procRow.proc.pid)
      }
    }

    Button {
      id: killBtn
      text: "KILL"
      foreground: Color.urgent
      fontFamily: root.contentFontFamily
      fontSize: Style.font.caption
      horizontalPadding: Style.space(4)
      verticalPadding: Style.space(2)
      width: root.procBtnW
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      tooltipText: "Force kill " + procRow.proc.comm + " (" + procRow.proc.pid + ", SIGKILL)"
      onClicked: { if (hostWidget) hostWidget.killProcess(procRow.proc.pid, true) }
    }

    Button {
      id: termBtn
      text: "TERM"
      fontFamily: root.contentFontFamily
      fontSize: Style.font.caption
      horizontalPadding: Style.space(4)
      verticalPadding: Style.space(2)
      width: root.procBtnW
      anchors.right: killBtn.left
      anchors.verticalCenter: parent.verticalCenter
      tooltipText: "Terminate " + procRow.proc.comm + " (" + procRow.proc.pid + ", SIGTERM)"
      onClicked: { if (hostWidget) hostWidget.killProcess(procRow.proc.pid, false) }
    }

    Text {
      id: memText
      textFormat: Text.PlainText
      text: Model.fmtProcMem(procRow.proc)
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignRight
      width: root.procMemW
      anchors.right: termBtn.left
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
    }

    Text {
      id: cpuText
      textFormat: Text.PlainText
      text: Model.fmtPct(procRow.proc.cpu)
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignRight
      width: root.procNumW
      anchors.right: memText.left
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
    }
  }

  // Line graph of the last N samples. Nulls render as gaps so missing
  // polls don't drag the line to zero. Y ticks run from maxVal down to
  // minVal in tickStep increments, one gridline + label per tick.
  component HistoryGraph: Item {
    id: graph
    property var history: []
    property color lineColor: Color.accent
    property real minVal: 0
    property real maxVal: 100
    property real tickStep: 25
    // Unit suffix for the Y axis labels, e.g. "%" for usage, "°" for temp.
    property string unit: ""

    // Ticks land on multiples of tickStep within [minVal, maxVal], going
    // down from the highest fitting multiple (so a 0–120 scale with step
    // 25 ticks 100/75/50/25/0, leaving 120 as unlabeled headroom).
    readonly property real topTick: Math.floor(graph.maxVal / graph.tickStep) * graph.tickStep
    readonly property int tickCount: Math.max(2, Math.floor((graph.topTick - graph.minVal) / graph.tickStep) + 1)

    width: parent ? parent.width : 0
    implicitHeight: Style.space(120)
    height: Style.space(120)

    function tickLabel(v) {
      var n = Number(v)
      if (!isFinite(n)) return "--"
      return (n % 1 === 0 ? String(n) : n.toFixed(1)) + graph.unit
    }

    function tickY(tickValue, labelHeight) {
      var y = Model.yFor(tickValue, graph.minVal, graph.maxVal, graph.height - 4) + 2 - labelHeight / 2
      return Math.max(0, Math.min(graph.height - labelHeight, y))
    }

    // Y axis ticks in the left gutter, each centered on its gridline.
    Repeater {
      model: graph.tickCount
      Text {
        required property int index
        readonly property real tickValue: graph.topTick - index * graph.tickStep
        textFormat: Text.PlainText
        text: graph.tickLabel(tickValue)
        color: Qt.darker(root.contentForeground, 1.4)
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        width: Style.space(26)
        x: 0
        y: graph.tickY(tickValue, implicitHeight)
      }
    }

    Canvas {
      id: canvas
      anchors.fill: parent
      anchors.leftMargin: Style.space(30)
      renderStrategy: Canvas.Cooperative

      onPaint: {
        var ctx = getContext("2d")
        var w = width, h = height
        ctx.clearRect(0, 0, w, h)
        var hist = graph.history || []
        var n = hist.length
        if (n === 0) return

        // grid: one faint line per Y tick, aligned with the labels
        ctx.strokeStyle = Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10)
        ctx.lineWidth = 1
        for (var ti = 0; ti < graph.tickCount; ti++) {
          var tick = graph.topTick - ti * graph.tickStep
          var gy = Math.round(Model.yFor(tick, graph.minVal, graph.maxVal, h - 4)) + 2 + 0.5
          ctx.beginPath()
          ctx.moveTo(0, gy)
          ctx.lineTo(w, gy)
          ctx.stroke()
        }

        // "now" is on the right; oldest on the left. Stretch the stored
        // window across the full width.
        var max = Math.max(2, n)
        ctx.strokeStyle = graph.lineColor
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.beginPath()
        var penDown = false
        for (var i = 0; i < n; i++) {
          var v = hist[i]
          if (typeof v !== "number" || !isFinite(v)) { penDown = false; continue }
          var x = (i / (max - 1)) * w
          var y = Model.yFor(v, graph.minVal, graph.maxVal, h - 4) + 2
          if (!penDown) { ctx.moveTo(x, y); penDown = true }
          else ctx.lineTo(x, y)
        }
        ctx.stroke()
      }

      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      Connections {
        target: graph
        function onHistoryChanged() { canvas.requestPaint() }
        function onLineColorChanged() { canvas.requestPaint() }
      }
      Connections {
        target: root
        function onContentForegroundChanged() { canvas.requestPaint() }
      }
    }

    Text {
      visible: !graph.history || graph.history.length === 0
      textFormat: Text.PlainText
      text: "collecting…"
      color: Qt.darker(root.contentForeground, 1.4)
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.caption
      anchors.centerIn: parent
    }
  }
}
