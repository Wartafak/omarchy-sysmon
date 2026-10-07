#!/bin/bash
# Integration test for wartafak.sysmon.
# Part A (static) always runs: stats.sh schema + value ranges, Model.js loads.
# Part B (live) needs omarchy-shell running with the plugin enabled; it is
# skipped gracefully otherwise and leaves the panel closed (net-zero).
# Run with:  ./tests/integration.sh

set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ID="wartafak.sysmon"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

# --- Part A: stats.sh (no shell needed) ---

RAW="$("$DIR/stats.sh" 2>/dev/null)"
[ $? -eq 0 ] && [ -n "$RAW" ] && ok "stats.sh exits 0 with output" || fail "stats.sh exits 0 with output"

echo "$RAW" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null \
  && ok "stats.sh prints valid JSON" || fail "stats.sh prints valid JSON"

check() { CHECK_EXPR="$1" python3 -c 'import json,sys,os; d=json.loads(sys.stdin.read()); assert eval(os.environ["CHECK_EXPR"])' <<< "$RAW" 2>/dev/null; }

check '"cpu" in d and "cpu_temp" in d and "gpu" in d and "gpu_temp" in d' \
  && ok "has cpu/gpu keys" || fail "has cpu/gpu keys"
check '"gpu_vendor" in d and "gpu_name" in d and "gpu_short" in d' \
  && ok "has gpu identity keys" || fail "has gpu identity keys"
check '"cpu_model" in d and "cpu_threads" in d and "cpu_max_ghz" in d' \
  && ok "has cpu identity keys" || fail "has cpu identity keys"
check '"mem" in d and "mem_used_kb" in d and "mem_total_kb" in d' \
  && ok "has mem keys" || fail "has mem keys"

check '(d["cpu"] is None) or (0 <= d["cpu"] <= 100)' \
  && ok "cpu in 0-100 or null" || fail "cpu in 0-100 or null"
check '(d["cpu_temp"] is None) or (0 <= d["cpu_temp"] <= 125)' \
  && ok "cpu_temp sane or null" || fail "cpu_temp sane or null"
check '(d["gpu"] is None) or (0 <= d["gpu"] <= 100)' \
  && ok "gpu in 0-100 or null" || fail "gpu in 0-100 or null"
check '(d["gpu_temp"] is None) or (0 <= d["gpu_temp"] <= 125)' \
  && ok "gpu_temp sane or null" || fail "gpu_temp sane or null"
check '(d["mem"] is None) or (0 <= d["mem"] <= 100)' \
  && ok "mem in 0-100 or null" || fail "mem in 0-100 or null"
check '(d["mem_used_kb"] is None or d["mem_total_kb"] is None) or (0 < d["mem_used_kb"] <= d["mem_total_kb"])' \
  && ok "mem_used <= mem_total" || fail "mem_used <= mem_total"
check 'd["gpu_vendor"] in ("none","nvidia","amd","intel")' \
  && ok "gpu_vendor known" || fail "gpu_vendor known"
check 'len(d["gpu_short"] or "") <= 60 and len(d["gpu_name"] or "") <= 80' \
  && ok "gpu names bounded" || fail "gpu names bounded"
check '(d["cpu_threads"] is None) or (d["cpu_threads"] > 0)' \
  && ok "cpu_threads positive or null" || fail "cpu_threads positive or null"
check '(d["cpu_max_ghz"] is None) or (0 < d["cpu_max_ghz"] < 10)' \
  && ok "cpu_max_ghz sane or null" || fail "cpu_max_ghz sane or null"

# Schema is stable across polls.
RAW2="$("$DIR/stats.sh" 2>/dev/null)"
KEYS1="$(echo "$RAW" | python3 -c 'import json,sys; print(" ".join(sorted(json.loads(sys.stdin.read()).keys())))')"
KEYS2="$(echo "$RAW2" | python3 -c 'import json,sys; print(" ".join(sorted(json.loads(sys.stdin.read()).keys())))')"
[ "$KEYS1" = "$KEYS2" ] && [ -n "$KEYS1" ] \
  && ok "stable schema across polls" || fail "stable schema across polls"

# Model.js parses the live payload (same code QML runs).
echo "$RAW" | node -e 'let t="";process.stdin.on("data",c=>t+=c).on("end",()=>{const M=require("'"$DIR"'/Model.js");const s=M.parseStats(t);if(typeof s.cpu==="undefined"||typeof s.mem==="undefined"){console.error("missing fields");process.exit(1)}})' 2>/dev/null \
  && ok "Model.js parses live stats.sh output" || fail "Model.js parses live stats.sh output"

# --- Part B: live shell (skipped when the shell is not running or stale) ---

# The running shell only picks up new QML after a restart, so an "unknown"
# accessor (or no shell at all) means SKIP, not FAIL.
if ! omarchy-shell shell call "$ID" debugState '{}' 2>/dev/null | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
  echo "SKIP: live shell checks need omarchy-shell with $ID enabled (and restarted after QML edits)"
  echo "--- $PASS passed, $FAIL failed ---"
  [ "$FAIL" -eq 0 ]
  exit $?
fi

state() { omarchy-shell shell call "$ID" debugState '{}'; }
field() { python3 -c 'import json,sys; v=json.load(sys.stdin)["'"$1"'"]; print("True" if v is True else "False" if v is False else v if v is not None else "null")'; }

S="$(state)"
echo "$S" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null \
  && ok "debugState returns JSON" || fail "debugState returns JSON"

echo "$S" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); assert all(k in d for k in ("opened","cpu","gpu","mem","sampleCount","cpuHistLen","hasGpu"))' 2>/dev/null \
  && ok "debugState has expected fields" || fail "debugState has expected fields"

# hasGpu agrees with the vendor string.
VENDOR="$(echo "$S" | field gpuVendor)"
HASGPU="$(echo "$S" | field hasGpu)"
if { [ "$VENDOR" = "none" ] && [ "$HASGPU" = "False" ]; } || { [ "$VENDOR" != "none" ] && [ "$HASGPU" = "True" ]; }; then
  ok "hasGpu agrees with vendor ($VENDOR)"
else
  fail "hasGpu agrees with vendor (vendor=$VENDOR hasGpu=$HASGPU)"
fi

echo "$S" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); assert 0 <= d["sampleCount"] <= 300 and 0 <= d["cpuHistLen"] <= 300' 2>/dev/null \
  && ok "histories bounded (<=300)" || fail "histories bounded (<=300)"

# refresh is callable and a second poll keeps the schema.
omarchy-shell shell call "$ID" refresh '{}' >/dev/null 2>&1 \
  && ok "refresh callable" || fail "refresh callable"
sleep 3
S2="$(state)"
K1="$(echo "$S" | python3 -c 'import json,sys; print(" ".join(sorted(json.loads(sys.stdin.read()).keys())))')"
K2="$(echo "$S2" | python3 -c 'import json,sys; print(" ".join(sorted(json.loads(sys.stdin.read()).keys())))')"
[ "$K1" = "$K2" ] && ok "debugState schema stable" || fail "debugState schema stable"

# Panel open/close round-trip, left closed (net-zero).
omarchy-shell shell call "$ID" open '{}' >/dev/null 2>&1
sleep 1
[ "$(state | field opened)" = "True" ] && ok "open shows panel" || fail "open shows panel"
omarchy-shell shell call "$ID" close '{}' >/dev/null 2>&1
sleep 1
[ "$(state | field opened)" = "False" ] && ok "close hides panel" || fail "close hides panel"

# toggle flips both ways, ends closed.
omarchy-shell shell call "$ID" toggle '{}' >/dev/null 2>&1
sleep 1
[ "$(state | field opened)" = "True" ] && ok "toggle opens" || fail "toggle opens"
omarchy-shell shell call "$ID" toggle '{}' >/dev/null 2>&1
sleep 1
[ "$(state | field opened)" = "False" ] && ok "toggle closes" || fail "toggle closes"

echo "--- $PASS passed, $FAIL failed ---"
[ "$FAIL" -eq 0 ]
