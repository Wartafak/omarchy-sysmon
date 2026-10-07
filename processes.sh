#!/usr/bin/env bash
# wartafak.sysmon process sampler
# Prints one JSON array line: [{"pid":1,"comm":"systemd","cpu":0.3,"mem":0.1,"rss_kb":1234}, ...]
# cpu = share of total CPU capacity between two 0.5s-apart /proc snapshots
# (current usage — `ps` %CPU is a lifetime average and would mislead here).
# mem = RSS share of MemTotal; rss_kb is the exact RSS for absolute display.
# Sorted by cpu descending. PIDs that exit mid-sample are skipped. Names are sanitized for direct JSON embedding.
set -u

snap() {
  local out="$1" _ a b c d e f g h rest p pid st rss ticks comm
  read -r _ a b c d e f g h rest < /proc/stat
  echo "TOTAL $((a+b+c+d+e+f+g+h))" > "$out"
  for p in /proc/[0-9]*; do
    pid="${p#/proc/}"
    st="$(cat "$p/stat" 2>/dev/null)" || continue
    st="${st##*)}" # utime=$12 stime=$13 of the fields after "(comm)"
    set -- $st
    ticks="$((${12:-0}+${13:-0}))"
    rss="$(awk '{print $2}' "$p/statm" 2>/dev/null)" || continue
    [ -n "$rss" ] || continue
    comm="$(tr -d '"\\\t\n' < "$p/comm" 2>/dev/null | head -c 40)"
    [ -n "$comm" ] || comm="[$pid]"
    echo "$pid $ticks $rss $comm" >> "$out"
  done
}

S1="$(mktemp)"; S2="$(mktemp)"
trap 'rm -f "$S1" "$S2"' EXIT
snap "$S1"
sleep 0.5
snap "$S2"

PAGEKB="$(($(getconf PAGESIZE 2>/dev/null || echo 4096) / 1024))"
MEMTOTAL="$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)"

awk -v memtotal="$MEMTOTAL" -v pagekb="$PAGEKB" '
  FNR == NR { if ($1 == "TOTAL") tot1 = $2; else t1[$1] = $2; next }
  $1 == "TOTAL" { tot2 = $2; next }
  ($1 in t1) {
    dt = tot2 - tot1; if (dt <= 0) dt = 1
    dp = $2 - t1[$1]; if (dp < 0) dp = 0
    cpu = dp * 100.0 / dt
    comm = $0; sub(/^[^ ]+ [^ ]+ [^ ]+ /, "", comm)
    rsskb = $3 * pagekb
    mem = (memtotal > 0) ? rsskb * 100.0 / memtotal : 0
    printf "%f\t%d\t%s\t%.1f\t%.1f\t%d\n", cpu, $1, comm, cpu, mem, rsskb
  }' "$S1" "$S2" | sort -rn | awk -F'\t' '
  BEGIN { printf "[" }
  { if (NR > 1) printf ","; printf "{\"pid\":%d,\"comm\":\"%s\",\"cpu\":%s,\"mem\":%s,\"rss_kb\":%s}", $2, $3, $4, $5, $6 }
  END { print "]" }'
