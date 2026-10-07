# AGENTS.md — wartafak.sysmon

Omarchy shell bar-widget plugin (`wartafak.sysmon`): CPU/GPU/memory usage +
temps in the top bar, popup with 10-minute averages and history graphs.
Quickshell (QML) + bash. No build step, no dependencies, no CI.

## Architecture

- `stats.sh` — 2s poller printing one JSON line (`cpu`, `cpu_temp`, `gpu`,
  `gpu_temp`, `gpu_vendor/name/short`, `cpu_model/threads/max_ghz`, `mem`,
  `mem_used_kb`, `mem_total_kb`). Unavailable readings are literal `null`.
- `BarWidget.qml` — owns the poller and the 300-sample (10-minute)
  histories; `Panel.qml` only renders them via `hostWidget`.
- `Model.js` — pure logic shared by QML (`import "Model.js" as Model`) and
  Node tests (`require`). Keep it dependency-free and side-effect-free; the
  `module.exports` block must stay guarded (`typeof module !== "undefined"`
  — QML has no `module`).
- IPC surface is the `IpcHandler` block in `BarWidget.qml`: expose a new
  accessor as a root function plus a typed wrapper, e.g.
  `function debugState(): string { return root.debugState() }`.
  Query it with `omarchy-shell shell call wartafak.sysmon <name> '{}'`.

## Gotchas

- QML edits require `omarchy restart shell` — hot-reload does not
  re-execute an already-loaded plugin.
- A stale (unrestarted) shell answers IPC with `unknown`. The integration
  test treats non-JSON `debugState` output as SKIP, not FAIL — keep that
  behavior when extending it.
- `Number(null) === 0`, so null-guards in `Model.js` must be explicit
  `=== null/undefined/""` comparisons, never `Number()` coercion
  (see `fmtMemDetail`).

## Verify

```bash
omarchy plugin validate ~/.config/omarchy/plugins/wartafak.sysmon
node --test tests/      # no runner to install
./tests/integration.sh  # static stats.sh checks always run; live shell checks
                        # need omarchy-shell running AND restarted after QML edits
```

## Versioning (`manifest.json`, SemVer)

The version tells marketplace consumers "should I update", so bump it in
the same commit as any consumer-affecting change:

- User-visible fix (wrong readings, broken display/panel) → PATCH
- User-visible feature (new display, new IPC surface consumers use) → MINOR
- Breaking change (removed/renamed IPC, manifest kind changes) → MAJOR
- No bump for tests, docs, refactors, or diagnostics with no consumer —
  anything with no observable effect
