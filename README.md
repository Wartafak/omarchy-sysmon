# omarchy-sysmon

Omarchy shell plugin (`wartafak.sysmon`): CPU / GPU / memory usage and
temperature in the top bar, with a popup showing current values, 10-minute
averages, and line-graph history.

## Screenshots

Bar widget (right side of the top bar):

![Bar widget](screenshots/bar.png)

Popup panel — summary rings, current values, 10-minute averages, and
history graphs (scroll for GPU / memory sections):

![System Monitor popup](screenshots/panel.png)

## Install

```bash
omarchy plugin add https://github.com/Wartafak/omarchy-sysmon.git --enable
```

Or manually:

```bash
git clone https://github.com/Wartafak/omarchy-sysmon.git ~/.config/omarchy/plugins/wartafak.sysmon
omarchy plugin enable wartafak.sysmon --section right
```

If QML edits don't appear, run `omarchy restart shell` (hot-reload does not
re-execute an already-loaded plugin).

## Remove

```bash
omarchy plugin remove wartafak.sysmon
```

## How it works

- `stats.sh` polls every 2s and prints one JSON line: CPU usage (`/proc/stat`),
  CPU temp (coretemp hwmon → thermal zone → `sensors`), memory (`/proc/meminfo`),
  GPU auto-detected (NVIDIA via `nvidia-smi` → AMD via `gpu_busy_percent` sysfs →
  Intel). Static labels (CPU model/threads/boost, short GPU name) are re-read
  each poll, so labels follow whatever hardware the host has.
- `BarWidget.qml` owns the poller and the 300-sample (10-minute) histories.
- `Panel.qml` renders current values, 10-minute averages, and Canvas line graphs.
- `Model.js` holds pure-JS helpers, shared by QML and the unit tests.
- `debugState` IPC accessor for scripting and diagnosis.

## Files

- `manifest.json` — id `wartafak.sysmon`, kind `bar-widget`
- `BarWidget.qml` — compact readout (BarWidget base) + 2s poller + histories
- `Panel.qml` — popup with summary rings, current values, averages, graphs
- `stats.sh` — 2s collector, prints one JSON line per poll
- `Model.js` — pure helpers (parsing, history, formatting, graph mapping),
  shared by QML and the unit tests
- `tests/model.test.js` — unit tests, no dependencies
- `tests/integration.sh` — stats.sh schema test + live end-to-end via shell IPC

## Testing

All display decisions live in `Model.js` as dependency-free functions,
imported by `BarWidget.qml`/`Panel.qml` (`import "Model.js" as Model`) and
by Node directly — so the same code that runs in the shell runs under
test.

```bash
omarchy plugin validate ~/.config/omarchy/plugins/wartafak.sysmon
node --test tests/   # 38 unit tests, no runner to install
./tests/integration.sh  # static stats.sh checks always; live shell checks
                        # need omarchy-shell running (restart it after QML
                        # edits: hot-reload does not re-execute plugins)
```

The integration test validates the `stats.sh` JSON schema and value ranges
(cpu/gpu/mem 0–100 or null, sane temps, `mem_used <= mem_total`, known
`gpu_vendor`), then — when the live shell is available — drives the real
widget through `omarchy-shell shell call` and the `debugState` accessor,
asserting bounded histories, a callable `refresh`, and an open/close/toggle
round-trip that ends with the panel closed.
