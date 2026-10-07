#!/usr/bin/env bash
# wartafak.sysmon kill helper: killproc.sh TERM|KILL <pid>
# Validates args so QML can pass them as argv without shell interpolation.
# PID 1 is never signalled. Exit 2 = bad args, else kill's own exit code
# (non-zero when the caller may not signal the target).
set -u

sig="${1:-}"
pid="${2:-}"

[ "$sig" = "TERM" ] || [ "$sig" = "KILL" ] || { echo "bad signal: $sig" >&2; exit 2; }
[[ "$pid" =~ ^[0-9]+$ ]] || { echo "bad pid: $pid" >&2; exit 2; }
[ "$pid" -gt 1 ] || { echo "refusing pid $pid" >&2; exit 2; }

kill -s "$sig" "$pid"
