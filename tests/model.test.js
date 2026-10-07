// Unit tests for Model.js — run with:  node --test tests/
// No dependencies (uses only node:test + node:assert).

const { describe, it } = require("node:test")
const assert = require("node:assert/strict")
const M = require("../Model.js")

describe("HISTORY_LIMIT", () => {
  it("covers 10 minutes of 2s samples", () => {
    assert.equal(M.HISTORY_LIMIT, 300)
  })
})

describe("numOrNull", () => {
  it("passes numbers through", () => {
    assert.equal(M.numOrNull(0), 0)
    assert.equal(M.numOrNull(42.5), 42.5)
    assert.equal(M.numOrNull("12.3"), 12.3)
  })
  it("nulls blanks and missing values", () => {
    assert.equal(M.numOrNull(null), null)
    assert.equal(M.numOrNull(undefined), null)
    assert.equal(M.numOrNull(""), null)
  })
  it("nulls negatives and non-finite values", () => {
    assert.equal(M.numOrNull(-1), null)
    assert.equal(M.numOrNull(NaN), null)
    assert.equal(M.numOrNull(Infinity), null)
    assert.equal(M.numOrNull("nope"), null)
  })
})

describe("parseStats", () => {
  const full = JSON.stringify({
    cpu: 12.5, cpu_temp: 55.0,
    gpu: 33.0, gpu_temp: 60.0, gpu_vendor: "amd",
    gpu_name: "AMD Radeon", gpu_short: "AMD Radeon RX 6650 XT",
    cpu_model: "Intel(R) Core(TM) i5-10400F CPU @ 2.90GHz",
    cpu_threads: 12, cpu_max_ghz: 4.3,
    mem: 27.1, mem_used_kb: 4414380, mem_total_kb: 16302004
  })
  it("parses a full stats.sh payload", () => {
    const s = M.parseStats(full)
    assert.equal(s.cpu, 12.5)
    assert.equal(s.cpuTemp, 55.0)
    assert.equal(s.gpu, 33.0)
    assert.equal(s.gpuTemp, 60.0)
    assert.equal(s.gpuVendor, "amd")
    assert.equal(s.gpuShort, "AMD Radeon RX 6650 XT")
    assert.equal(s.cpuThreads, 12)
    assert.equal(s.cpuMaxGhz, 4.3)
    assert.equal(s.mem, 27.1)
    assert.equal(s.memUsedKb, 4414380)
    assert.equal(s.memTotalKb, 16302004)
  })
  it("keeps nulls from stats.sh as null", () => {
    const s = M.parseStats('{"cpu":null,"cpu_temp":null,"gpu":null,"gpu_temp":null,"gpu_vendor":"none","gpu_name":"","gpu_short":"","cpu_model":"","cpu_threads":null,"cpu_max_ghz":null,"mem":null,"mem_used_kb":null,"mem_total_kb":null}')
    assert.equal(s.cpu, null)
    assert.equal(s.gpuVendor, "none")
    assert.equal(s.cpuThreads, null)
  })
  it("falls back on invalid JSON", () => {
    const s = M.parseStats("not json")
    assert.equal(s.cpu, null)
    assert.equal(s.gpuVendor, "none")
    assert.equal(s.mem, null)
  })
  it("falls back on empty / missing input", () => {
    for (const raw of ["", null, undefined]) {
      const s = M.parseStats(raw)
      assert.equal(s.cpu, null)
      assert.equal(s.gpuVendor, "none")
    }
  })
  it("falls back on non-object JSON", () => {
    assert.equal(M.parseStats("[1,2]").cpu, null)
    assert.equal(M.parseStats("42").cpu, null)
  })
  it("rejects negative and non-numeric readings", () => {
    const s = M.parseStats('{"cpu":-5,"cpu_temp":"hot","mem":"-1"}')
    assert.equal(s.cpu, null)
    assert.equal(s.cpuTemp, null)
    assert.equal(s.mem, null)
  })
  it("rejects non-positive thread counts", () => {
    assert.equal(M.parseStats('{"cpu_threads":0}').cpuThreads, null)
    assert.equal(M.parseStats('{"cpu_threads":-4}').cpuThreads, null)
    assert.equal(M.parseStats('{"cpu_threads":"x"}').cpuThreads, null)
  })
})

describe("pushHistory", () => {
  it("appends values", () => {
    assert.deepEqual(M.pushHistory([1, 2], 3, 10), [1, 2, 3])
  })
  it("keeps nulls so gaps render as gaps", () => {
    assert.deepEqual(M.pushHistory([1], null, 10), [1, null])
    assert.deepEqual(M.pushHistory([], undefined, 10), [null])
  })
  it("caps at the limit", () => {
    assert.deepEqual(M.pushHistory([1, 2, 3], 4, 3), [2, 3, 4])
  })
  it("defaults to HISTORY_LIMIT for bad limits", () => {
    const out = M.pushHistory([], 1, 0)
    assert.equal(out.length, 1)
    const big = Array.from({ length: 310 }, (_, i) => i)
    assert.equal(M.pushHistory(big, 999).length, M.HISTORY_LIMIT)
  })
  it("starts from empty on non-arrays", () => {
    assert.deepEqual(M.pushHistory(null, 5, 10), [5])
    assert.deepEqual(M.pushHistory("x", 5, 10), [5])
  })
  it("does not mutate the input", () => {
    const src = [1, 2]
    M.pushHistory(src, 3, 10)
    assert.deepEqual(src, [1, 2])
  })
})

describe("average", () => {
  it("averages plain samples", () => {
    assert.equal(M.average([10, 20, 30]), 20)
  })
  it("skips gaps and non-numbers", () => {
    assert.equal(M.average([10, null, 20, undefined, "x", NaN]), 15)
  })
  it("returns null when there is nothing to average", () => {
    assert.equal(M.average([]), null)
    assert.equal(M.average([null, null]), null)
    assert.equal(M.average(null), null)
  })
})

describe("fmtPct", () => {
  it("uses one decimal below 10", () => {
    assert.equal(M.fmtPct(6.15), "6.2%")
  })
  it("uses no decimals at 10 and above", () => {
    assert.equal(M.fmtPct(27.1), "27%")
    assert.equal(M.fmtPct(100), "100%")
  })
  it("dashes missing values", () => {
    assert.equal(M.fmtPct(null), "--")
    assert.equal(M.fmtPct(undefined), "--")
    assert.equal(M.fmtPct(NaN), "--")
  })
})

describe("fmtTemp", () => {
  it("rounds to whole degrees", () => {
    assert.equal(M.fmtTemp(35.6), "36°")
    assert.equal(M.fmtTemp(35.0), "35°")
  })
  it("dashes missing values", () => {
    assert.equal(M.fmtTemp(null), "--")
    assert.equal(M.fmtTemp("hot"), "--")
  })
})

describe("fmtMemDetail", () => {
  it("formats used/total GiB", () => {
    assert.equal(M.fmtMemDetail(4414380, 16302004), "4.2 / 15.5 GB")
  })
  it("blanks when total is missing", () => {
    assert.equal(M.fmtMemDetail(100, 0), "")
    assert.equal(M.fmtMemDetail(100, null), "")
    assert.equal(M.fmtMemDetail(null, 16302004), "")
  })
})

describe("shortCpuName", () => {
  it("shortens a full Intel model string", () => {
    assert.equal(
      M.shortCpuName("Intel(R) Core(TM) i5-10400F CPU @ 2.90GHz", 12, 4.3),
      "Intel Core i5-10400F (12) @ 4.30 GHz"
    )
  })
  it("omits missing parts", () => {
    assert.equal(M.shortCpuName("AMD Ryzen 5", null, null), "AMD Ryzen 5")
    assert.equal(M.shortCpuName("AMD Ryzen 5", 12, null), "AMD Ryzen 5 (12)")
  })
  it("blanks on empty model", () => {
    assert.equal(M.shortCpuName("", 12, 4.3), "")
    assert.equal(M.shortCpuName(null, null, null), "")
  })
})

describe("titles", () => {
  it("cpuTitle prefixes the short name", () => {
    assert.equal(
      M.cpuTitle({ cpuModel: "Intel(R) Core(TM) i5-10400F CPU @ 2.90GHz", cpuThreads: 12, cpuMaxGhz: 4.3 }),
      "CPU · Intel Core i5-10400F (12) @ 4.30 GHz"
    )
    assert.equal(M.cpuTitle({}), "CPU")
    assert.equal(M.cpuTitle(null), "CPU")
  })
  it("gpuTitle prefixes the short name", () => {
    assert.equal(M.gpuTitle({ gpuShort: "AMD Radeon RX 6650 XT" }), "GPU · AMD Radeon RX 6650 XT")
    assert.equal(M.gpuTitle({ gpuShort: "" }), "GPU")
    assert.equal(M.gpuTitle(null), "GPU")
  })
  it("memTitle shows total GiB when known", () => {
    assert.equal(M.memTitle({ memTotalKb: 16302004 }), "MEMORY · 15.5 GiB")
    assert.equal(M.memTitle({}), "MEMORY")
    assert.equal(M.memTitle(null), "MEMORY")
  })
})

describe("yFor", () => {
  it("maps min to bottom and max to top", () => {
    assert.equal(M.yFor(0, 0, 100, 100), 100)
    assert.equal(M.yFor(100, 0, 100, 100), 0)
    assert.equal(M.yFor(50, 0, 100, 100), 50)
  })
  it("clamps out-of-range values", () => {
    assert.equal(M.yFor(-10, 0, 100, 100), 100)
    assert.equal(M.yFor(150, 0, 100, 100), 0)
  })
  it("yields NaN for gaps and height for bad scales", () => {
    assert.ok(Number.isNaN(M.yFor(null, 0, 100, 100)))
    assert.equal(M.yFor(50, 100, 100, 100), 100)
  })
})

describe("xFor", () => {
  it("stretches first..last across the width", () => {
    assert.equal(M.xFor(0, 4, 300), 0)
    assert.equal(M.xFor(3, 4, 300), 300)
    assert.equal(M.xFor(1, 3, 200), 100)
  })
  it("parks single samples on the right", () => {
    assert.equal(M.xFor(0, 1, 300), 300)
  })
})
