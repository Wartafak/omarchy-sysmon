// wartafak.sysmon data helpers - pure JS, Node-testable.
var HISTORY_LIMIT = 300; // 2s samples x 300 = 10 minutes

function numOrNull(v) {
  if (v === null || v === undefined || v === "") return null;
  var n = Number(v);
  if (!isFinite(n) || n < 0) return null;
  return n;
}

function parseStats(raw) {
  var fallback = {
    cpu: null, cpuTemp: null,
    gpu: null, gpuTemp: null, gpuVendor: "none", gpuName: "", gpuShort: "",
    cpuModel: "", cpuThreads: null, cpuMaxGhz: null,
    mem: null, memUsedKb: null, memTotalKb: null
  };
  var parsed;
  try {
    parsed = JSON.parse(String(raw || ""));
  } catch (e) {
    return fallback;
  }
  if (!parsed || typeof parsed !== "object") return fallback;
  var threads = parsed.cpu_threads === null || parsed.cpu_threads === undefined
    ? null : parseInt(parsed.cpu_threads, 10);
  if (!isFinite(threads) || threads <= 0) threads = null;
  return {
    cpu: numOrNull(parsed.cpu),
    cpuTemp: numOrNull(parsed.cpu_temp),
    gpu: numOrNull(parsed.gpu),
    gpuTemp: numOrNull(parsed.gpu_temp),
    gpuVendor: typeof parsed.gpu_vendor === "string" ? parsed.gpu_vendor : "none",
    gpuName: typeof parsed.gpu_name === "string" ? parsed.gpu_name : "",
    gpuShort: typeof parsed.gpu_short === "string" ? parsed.gpu_short : "",
    cpuModel: typeof parsed.cpu_model === "string" ? parsed.cpu_model : "",
    cpuThreads: threads,
    cpuMaxGhz: numOrNull(parsed.cpu_max_ghz),
    mem: numOrNull(parsed.mem),
    memUsedKb: numOrNull(parsed.mem_used_kb),
    memTotalKb: numOrNull(parsed.mem_total_kb)
  };
}

// Push value onto history array, capped at limit. Nulls are kept so gaps
// render as gaps instead of shifting the time axis.
function pushHistory(history, value, limit) {
  var list = Array.isArray(history) ? history.slice() : [];
  list.push(value === undefined ? null : value);
  var max = Math.max(1, parseInt(limit, 10) || HISTORY_LIMIT);
  while (list.length > max) list.shift();
  return list;
}

function average(history) {
  var list = Array.isArray(history) ? history : [];
  var total = 0, count = 0;
  for (var i = 0; i < list.length; i++) {
    var v = list[i];
    if (typeof v !== "number" || !isFinite(v)) continue;
    total += v;
    count++;
  }
  if (count === 0) return null;
  return total / count;
}

function fmtPct(v) {
  if (typeof v !== "number" || !isFinite(v)) return "--";
  return v.toFixed(v < 10 ? 1 : 0) + "%";
}

function fmtTemp(v) {
  if (typeof v !== "number" || !isFinite(v)) return "--";
  return v.toFixed(0) + "°";
}

function fmtMemDetail(usedKb, totalKb) {
  var u = Number(usedKb), t = Number(totalKb);
  if (!isFinite(u) || !isFinite(t) || t <= 0) return "";
  return (u / 1048576).toFixed(1) + " / " + (t / 1048576).toFixed(1) + " GB";
}

// "Intel(R) Core(TM) i5-10400F CPU @ 2.90GHz" + 12 + 4.3
// -> "Intel Core i5-10400F (12) @ 4.30 GHz"
function shortCpuName(model, threads, maxGhz) {
  var name = String(model || "").replace(/\(R\)|\(TM\)/g, "").replace(/\s+/g, " ").trim();
  // Drop the stock "CPU @ <base freq>" tail; we show max boost instead.
  name = name.replace(/\s*CPU\s*@.*$/i, "").trim();
  if (name === "") return "";
  var suffix = "";
  var th = parseInt(threads, 10);
  if (isFinite(th) && th > 0) suffix += " (" + th + ")";
  var ghz = Number(maxGhz);
  if (isFinite(ghz) && ghz > 0) suffix += " @ " + ghz.toFixed(2) + " GHz";
  return name + suffix;
}

function cpuTitle(s) {
  var v = s || {};
  var label = shortCpuName(v.cpuModel, v.cpuThreads, v.cpuMaxGhz);
  return label !== "" ? "CPU · " + label : "CPU";
}

function gpuTitle(s) {
  var v = s || {};
  var label = String(v.gpuShort || "").trim();
  return label !== "" ? "GPU · " + label : "GPU";
}

// Brand/model/freq need root (dmidecode); all we can read is total size.
function memTitle(s) {
  var v = s || {};
  var t = Number(v.memTotalKb);
  if (isFinite(t) && t > 0) return "MEMORY · " + (t / 1048576).toFixed(1) + " GiB";
  return "MEMORY";
}

// Map a value in [min,max] to a Y pixel in [0,height] (0 = top).
function yFor(value, min, max, height) {
  var lo = Number(min), hi = Number(max), h = Number(height);
  if (!isFinite(lo) || !isFinite(hi) || hi <= lo) return h;
  if (typeof value !== "number" || !isFinite(value)) return NaN;
  var clamped = Math.max(lo, Math.min(hi, value));
  return h - ((clamped - lo) / (hi - lo)) * h;
}

// X pixel for sample index i of count points in width.
function xFor(i, count, width) {
  var n = Math.max(1, parseInt(count, 10) || 1);
  var w = Number(width);
  if (n <= 1) return w;
  return (i / (n - 1)) * w;
}

if (typeof module !== "undefined") {
  module.exports = {
    HISTORY_LIMIT: HISTORY_LIMIT,
    numOrNull: numOrNull,
    parseStats: parseStats,
    pushHistory: pushHistory,
    average: average,
    fmtPct: fmtPct,
    fmtTemp: fmtTemp,
    fmtMemDetail: fmtMemDetail,
    shortCpuName: shortCpuName,
    cpuTitle: cpuTitle,
    gpuTitle: gpuTitle,
    memTitle: memTitle,
    yFor: yFor,
    xFor: xFor
  };
}
