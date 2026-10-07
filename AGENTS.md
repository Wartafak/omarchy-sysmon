# AGENTS.md — wartafak.sysmon

Omarchy shell bar-widget plugin (`wartafak.sysmon`): CPU/GPU/memory usage +
temps in the top bar, popup with 10-minute averages and history graphs.
Quickshell (QML) + bash. No build step, no dependencies, no CI.

## Architecture

- `stats.sh` — 2s poller printing one JSON line (`cpu`, `cpu_temp`, `gpu`,
  `gpu_temp`, `gpu_vendor/name/short`, `cpu_model/threads/max_ghz`, `mem`,
  `mem_used_kb`, `mem_total_kb`). Unavailable readings are literal `null`.
- `processes.sh` — 2s poller printing one JSON array
  (`[{pid,comm,cpu,mem,rss_kb}]`, cpu-desc). Sampled only while the panel is open.
- `killproc.sh` — `TERM|KILL <pid>` with strict arg validation (never pid 1);
  QML passes args as argv, never shell-interpolated.
- `BarWidget.qml` — owns both pollers and the 300-sample (10-minute)
  histories; `Panel.qml` only renders them via `hostWidget`.
- `Model.js` — pure logic shared by QML (`import "Model.js" as Model`) and
  Node tests (`require`). Keep it dependency-free and side-effect-free; the
  `module.exports` block must stay guarded (`typeof module !== "undefined"`
  — QML has no `module`).
- IPC surface is the `IpcHandler` block in `BarWidget.qml`: expose a new
  accessor as a root function plus a typed wrapper, e.g.
  `function debugState(): string { return root.debugState() }`.
  Query it with quickshell's native IPC:
  `quickshell --path /usr/share/omarchy/shell ipc call wartafak.sysmon <name>`.
  `omarchy-shell shell call` does NOT reach bar-widget `IpcHandler`s — it
  only routes to panel/overlay plugins (see `callIfLoaded` in the shell's
  `shell.qml`).

## Gotchas

- QML edits require `omarchy restart shell` — hot-reload does not
  re-execute an already-loaded plugin.
- A stale (unrestarted) shell answers IPC with `unknown`. The integration
  test treats non-JSON `debugState` output as SKIP, not FAIL — keep that
  behavior when extending it.
- `Number(null) === 0`, so null-guards in `Model.js` must be explicit
  `=== null/undefined/""` comparisons, never `Number()` coercion
  (see `fmtMemDetail`).
- QQC2 `ScrollView` has no `contentItem` — programmatic scroll must drive
  the attached scrollbar instead, e.g.
  `scrollArea.ScrollBar.vertical.position = fraction` (0..1, writable).
  The fraction maps over the FULL `contentHeight`
  (`contentY = position × contentHeight`, visibleArea semantics) — dividing
  by `contentHeight - height` overshoots.
  Verified against Qt's `plugins.qmltypes`, not docs.
- `Repeater` delegates must declare `required property var modelData`
  (auto-filled per row). Never pass it from the delegate site
  (`delegate: ProcRow { proc: modelData }` throws: bindings on an inline
  `component` instance resolve in the definition scope, where `modelData`
  does not exist).

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

## Docs

- The README `Features` section lists every user-visible feature. Update
  it in the same commit as any feature or behavior change — a feature
  without a `Features` entry is unfinished.
