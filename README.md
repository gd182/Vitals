<h1 align="center">Vitals</h1>

<p align="center">
  A lightweight macOS menu bar monitor for CPU, GPU, and RAM — built with a C++ core and SwiftUI frontend
</p>

###

<div align="center">
  <img src="https://skillicons.dev/icons?i=swift" height="40" alt="Swift logo" />
  <img width="12" />
  <img src="https://skillicons.dev/icons?i=cpp" height="40" alt="C++ logo" />
</div>

###

<p align="center">
  <b>English</b> · <a href="README.ru.md">Русский</a>
</p>

## About

Vitals is a macOS menu bar application that surfaces CPU, GPU, and RAM statistics in real time. The data pipeline — hardware polling, process enumeration, and sensor reading — is implemented in C++20 with no third-party dependencies. SwiftUI renders everything: live indicators in the menu bar, a popover dashboard with reorderable blocks, gradient history charts, and a settings window.

Built as a learning project exploring the boundary between a Swift/SwiftUI frontend and a native C++ core connected through an Objective-C++ bridge.

## What it monitors

| Section | Metrics |
|---|---|
| CPU | Usage, temperature, system / user / idle breakdown, top processes by CPU |
| GPU | Utilization, render load, tiler load, Neural Engine (ANE) load, VRAM used / total |
| RAM | Memory pressure, used / free / total, top processes by RAM |

## How it works

Each update cycle runs two stages:

1. **C++ core** — `CPUStats`, `GPUStats`, `MemoryStats`, and `ProcessStats` query IOKit, the SMC, and `/bin/ps` directly. Results are collected into plain structs and handed to the bridge.

2. **SwiftUI frontend** — `SystemViewModel` holds all published state and drives a timer. Views observe the view model through `@EnvironmentObject` and re-render only the sub-view whose data actually changed. The dashboard is a `ForEach` over a stable `[DashboardBlock]` array; blocks are static value types (`BlockContent` enum), so SwiftUI can diff them correctly and popovers stay anchored.

## Architecture

Vitals is split into three layers:

- `Core/` — C++20 collectors for CPU, GPU, memory, sensors, and processes.
- `Bridge/` — Objective-C++ wrapper that exposes native metrics to Swift.
- `ViewModels/` and `Views/` — SwiftUI state, menu bar UI, dashboard, charts, and settings.

## Requirements

- macOS 13 Ventura or later
- Xcode 15+
- Apple Silicon or Intel Mac

## Build

```bash
git clone https://github.com/gd182/Vitals.git
cd Vitals
open Vitals.xcodeproj
```

No package manager, no external dependencies. Select the `Vitals` scheme and press `Cmd+R`.

## Dev tools

`test/load.py` — Python CPU stress tester. Spawns one busy-loop worker per core and ramps to a target load percentage:

```bash
python3 test/load.py 80     # 80% CPU load
python3 test/load.py 50 5   # ramp to 50% over 5 seconds
```

Useful for verifying that charts, thresholds, and menu bar indicators respond correctly under real load.

## License

MIT — see [LICENSE](LICENSE).
