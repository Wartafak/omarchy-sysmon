import QtQuick
import QtQuick.Controls
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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
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
          Item {
            width: parent.width
            implicitHeight: summaryRow.implicitHeight
            height: summaryRow.height

            Row {
              id: summaryRow
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(20)

              SummaryCard {
                title: "CPU"
                usage: hostWidget ? hostWidget.cpu : null
                subText: hostWidget ? Model.fmtTemp(hostWidget.cpuTemp) : "--"
                subColor: hostWidget ? hostWidget.themeTemp : "#e0af68"
                ringColor: Color.accent
              }

              SummaryCard {
                visible: hostWidget ? hostWidget.hasGpu : false
                title: "GPU"
                usage: hostWidget ? hostWidget.gpu : null
                subText: hostWidget ? Model.fmtTemp(hostWidget.gpuTemp) : "--"
                subColor: hostWidget ? hostWidget.themeTemp : "#e0af68"
                ringColor: Color.accent
              }

              SummaryCard {
                title: "MEMORY"
                usage: hostWidget ? hostWidget.mem : null
                // show GB detail under the ring when available; NOW info only
                detailText: hostWidget ? Model.fmtMemDetail(hostWidget.memUsedKb, hostWidget.memTotalKb) : ""
                ringColor: hostWidget ? hostWidget.themeGreen : "#9ece6a"
              }
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
