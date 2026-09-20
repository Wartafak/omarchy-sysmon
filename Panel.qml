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

          // ---------- CPU ----------
          PanelSeparator { foreground: root.contentForeground }

          PanelSectionHeader {
            text: root.cpuHeader()
            width: parent.width
            elide: Text.ElideRight
            foreground: root.contentForeground
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
            lineColor: "#e0af68"
            minVal: 0
            maxVal: 100
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
            foreground: root.contentForeground
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
            lineColor: "#e0af68"
            minVal: 0
            maxVal: 100
          }

          // ---------- Memory ----------
          PanelSeparator { foreground: root.contentForeground }

          PanelSectionHeader {
            text: root.memHeader()
            width: parent.width
            elide: Text.ElideRight
            foreground: root.contentForeground
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
            lineColor: "#9ece6a"
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
  // polls don't drag the line to zero.
  component HistoryGraph: Item {
    id: graph
    property var history: []
    property color lineColor: Color.accent
    property real minVal: 0
    property real maxVal: 100

    width: parent ? parent.width : 0
    implicitHeight: Style.space(84)
    height: Style.space(84)

    Canvas {
      id: canvas
      anchors.fill: parent
      renderStrategy: Canvas.Cooperative

      onPaint: {
        var ctx = getContext("2d")
        var w = width, h = height
        ctx.clearRect(0, 0, w, h)
        var hist = graph.history || []
        var n = hist.length
        if (n === 0) return

        // grid: 3 faint horizontal lines
        ctx.strokeStyle = Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
        ctx.lineWidth = 1
        for (var g = 0; g <= 2; g++) {
          var gy = Math.round((h - 1) * g / 2) + 0.5
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
