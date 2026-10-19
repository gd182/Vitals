# Performance Measurements

Measure before changing the collectors or UI. Local exploratory measurements
are recorded below. Passing functional tests does not establish a performance budget.

## Preparation

- Record the commit, Mac model, CPU, RAM, macOS and Xcode versions, and whether
  the app runs natively or through Rosetta. Compare changes on the same machine;
  an Apple Silicon measurement is not evidence of Intel performance.
- Use a Release build. For an uninstrumented baseline, launch the app from
  Finder without the debugger. Quit any other running copy of Vitals first.
- Record foreground, background, process and temperature intervals, visible
  menu modules, temperature availability and panel layout. Keep them unchanged
  between runs. Record explicit values rather than assuming fresh-install defaults.
- Keep power source, Low Power Mode, display setup and other workloads stable.
  Avoid builds, indexing and stress tools during the initial idle measurements.
- Disable automatic update checks for the monitoring baseline, and record that
  choice. Measure an enabled-but-not-due scheduler and actual requests separately.
- Allow 60 seconds after launch or changing a scenario before recording a
  120-second observation window. Repeat each steady-state scenario three times.

## Scenarios

| Scenario | Conditions |
| --- | --- |
| Background | All panels and settings closed; normal menu modules visible. |
| CPU panel | Only the CPU panel open; record visible process and temperature sections. |
| RAM panel | Only the RAM panel open; record whether its process section is visible. |
| GPU panel | Only the GPU panel open; record available counters. |
| After closing | Close the panel and observe recovery to background activity. |
| Repeated opening | Open and close the same panel 20 times, then observe for five minutes. Record memory before and after; account for bounded caches rather than treating every increase as a leak. |
| Sleep/wake | Sleep and wake the Mac; verify monitoring resumes without duplicate work. Record sleep duration. |

## What to Record

### Detailed Process Report

From the repository root, with exactly one Vitals process running:

```sh
python3 test/profile_process.py --warmup 60 --duration 120 --interval 5 \
  --label 'background; foreground=1s background=1s processes=2s temperature=3s' \
  --output test/tests_results/vitals-background-01
```

This standalone macOS tool needs Python 3.9 or newer and no external packages.
It does not change Vitals, run stress loads or start the app. It resolves the
process once and reads libproc counters directly, without spawning a command at
every interval. If several copies are running, use `--pid 12345` instead of name
lookup. A missing process, access failure or changed process identity stops the
measurement rather than silently attaching to a different process.

The default measurement lasts 120 seconds at five-second intervals, with no
warmup unless requested. Ctrl+C prints a partial summary and saves the collected
data. Reports default to `test/tests_results/` beside the script, with a timestamp
in each filename, regardless of the working directory. This directory is ignored
by Git. Use `--output` to choose another prefix; missing parent directories are
created automatically. Existing output files are never overwritten, so use a
different prefix for each run when specifying one explicitly.

For steady-state measurements, keep the Mac awake. A significant disagreement
between wall-clock and monotonic elapsed time stops the run with partial results,
since sleep or a clock adjustment makes the observation window discontinuous.
Such a run is not a completed steady-state baseline. To inhibit idle system
sleep only while measuring, prefix the command with `caffeinate -i`; do not close
the lid or manually put the Mac to sleep. Sleep/wake is a separate scenario.

The console shows CPU total/user/system percentages, RSS, physical footprint,
wired memory, virtual address space, thread counts, two distinct wakeup counters,
context switches, faults, page-ins, Mach/Unix calls and accounted disk I/O rates.
Memory is shown in bytes and MiB, not rounded to whole megabytes. Missing task
information is reported as N/A rather than zero. Virtual address space is not
physical memory, and package-idle and interrupt wakeups must not be added together.
Disk counters do not represent every application read/write call.

CPU is calculated from counter differences over the actual monotonic interval;
100% means one logical CPU and multithreaded use can exceed 100%. Mach CPU ticks
are converted using the host's timebase instead of assuming Intel timing on
Apple Silicon. No CPU percentage is reported for the initial baseline itself.

The CSV contains timestamped samples with explicit units in column names. The
JSON includes hardware/observer metadata, the scenario label, interval-weighted
means, sampled minima/maxima, total counter changes and start/end memory values.
Memory means use interval-end observations weighted by interval length, not a
continuous trace. Peaks between observations may be missed. The observer's
architecture is not necessarily the target process's architecture; record
Rosetta use separately. Put the tested commit and relevant settings in the label.

The tool does not collect GPU utilization, network bytes, watts, Energy Impact
or allocation call stacks. Use Instruments for those investigations where
supported. Its own sampling overhead is not subtracted. This tool and its tests
have been exercised locally on Apple Silicon; real Intel validation is pending.

Run its focused calculation and macOS integration checks separately:

```sh
python3 -B -m unittest discover -s Tests -p test_profile_process.py -v
```

### Instruments and Activity Monitor

Use Activity Monitor for a first look at Vitals' CPU and Memory columns. Note its
update frequency and record several readings across the observation window;
a single screenshot or the highest visible CPU value is not an average.

Use Instruments Time Profiler to identify expensive call stacks, then use
Allocations for allocation growth. Keep these traces separate from uninstrumented
measurements: the tools themselves add overhead. Record the precise instrument
and units for wakeups or energy measurements, if collected. Do not equate timer
fires, context switches, wakeups and Energy Impact.

Do not mix Activity Monitor memory, resident size and physical footprint in one
comparison. Label the metric and tool, and use the same one before and after.
Keep raw traces locally; they may contain private paths or process names.

## Local Menu-Bar Experiment

On October 18-19, 2026, the working tree on `perf/monitoring-baseline` was
measured on an Apple M5 Max (18 logical CPUs, 48 GiB RAM), macOS 27.0.1.
These are uncommitted development snapshots, not reproducible release benchmarks.
Background runs used closed panels and settings, CPU/RAM/GPU menu modules,
foreground/background intervals of 1 s, process interval of 2 s, temperature
interval of 3 s, and automatic update checks disabled.

The comparison used three completed libproc runs per implementation, each with
60 s warmup and 120 s measurement. Each row below is the arithmetic mean of the
three interval-weighted run means.

| Metric | Independent metrics with SwiftUI labels | Native menu-button images |
| --- | --- | --- |
| CPU (100% = one logical CPU) | 1.74% | 1.07% |
| Physical footprint | 24.10 MiB | 22.37 MiB |
| Resident size | 87.78 MiB | 88.14 MiB |
| Interrupt wakeups | 4.30/s | 6.21/s |
| Context switches | 35.47/s | 42.89/s |

Local report filename stems (under the ignored `test/tests_results/` directory):

- SwiftUI: `vitals-20261018-185853-275507`, `vitals-20261018-192814-135903`,
  `vitals-20261018-193155-004340`.
- Native images: `vitals-20261019-021515-481340`, `vitals-20261019-022039-695460`,
  `vitals-20261019-022341-433148`.

CPU decreased in these runs, but interrupt wakeups increased. The runs were
collected at different times rather than alternating old/new builds, so workload
and system-state differences remain confounders. This is not an energy-use claim.
The new implementation's repeated runs showed no sustained footprint growth;
short runs do not establish the absence of a memory leak.

A subsequent Time Profiler screenshot showed 223 ms under status-item snapshot
redrawing and 28 ms under its layout subtree, without the previous SwiftUI hosting
layout chain in that expanded branch. An earlier recording showed 817 ms and
556 ms respectively, with `NSHostingView.layout()` beneath layout. The earlier
recording's executable identity and equal selected durations were not established,
so these screenshots support inspecting the changed call path, not a quantified
speedup. Confirm the executable path and PID before future recordings.

Manual smoke testing was reported successful by the developer. After 20 CPU-panel
open/close cycles, a completed 300 s run with 60 s warmup (60 samples, report
`vitals-20261019-141549-680206`, PID 13939) recorded 0.96% mean CPU, 40.95 MiB
mean footprint, 109.07 MiB mean resident size and 5.86 interrupt wakeups/s.
Footprint increased by 80 KiB and resident size by 64 KiB during observation.
This shows little post-close growth during that window, not the absence of
per-opening retention: the recording began after the cycles, with no same-process
pre-cycle baseline. Repeat cycles in the same process to distinguish a bounded
plateau from cumulative retention.

After another 20 cycles without restarting (40 total, same PID 13939), report
`vitals-20261019-142542-753178` completed another 300 s observation with 60 samples.
Mean CPU was 1.01%, footprint was 41.25 MiB and resident size was 108.88 MiB;
interrupt wakeups averaged 5.64/s. Footprint and resident size were unchanged
throughout that observation. Footprint was about 0.25 MiB above the first run's
ending value. These two batches do not show large cumulative retention, but do
not prove a bounded cache or exclude smaller per-cycle leaks. No allocation
ownership trace was collected.

With the CPU panel left open, report `vitals-20261019-143302-199250` (same PID
13939, 60 s warmup, completed 120 s observation, 24 samples) recorded 2.34% mean
CPU, 232.92 MiB mean footprint, 110.90 MiB mean resident size and 11.43 interrupt
wakeups/s. Footprint decreased by 7.92 MiB during observation, ending at
232.63 MiB. This is a substantial panel-open footprint increase relative to the
preceding closed-panel run, not evidence of continuous growth or identification
of the responsible allocation category. A subsequent closed-panel recovery run
is still required; process counters cannot attribute this difference to objects
or rendering resources.

The subsequent closed-panel report `vitals-20261019-152050-911433` used the same
PID 13939 and completed 300 s with 60 samples after 60 s warmup. Mean CPU was
1.02%, footprint 42.16 MiB, resident size 110.98 MiB and interrupt wakeups 5.68/s.
Footprint and resident size had zero net change; sampled footprint spanned only
32 KiB. The large panel-open footprint was no longer present by this recording.
The report started about 48 minutes after the panel-open report started, and the
exact closing time was not recorded, so recovery latency cannot be inferred.
The remaining difference from the earlier closed-panel run does not identify a
leak or a particular cache.

Outstanding work: explain the wakeup increase, validate panel-open and additional
repeated-open scenarios, and repeat on Intel hardware. Preserve raw reports
locally; they are not committed.

## Optimization Loop

Identify the expensive stack or growing allocation before changing code. Make
one focused change, run functional checks, and repeat the same scenarios. Keep
changes only when measurements support them and behavior remains correct.
Moving Swift code to C or C++ is an option when the measured bottleneck benefits
from it, not a performance result by itself.

## References

- [Apple: Performance and metrics](https://developer.apple.com/documentation/xcode/performance-and-metrics)
- [Apple: Gathering information about memory use](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use)
- [Apple libproc interfaces](https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/wrappers/libproc/libproc.h)
- [Apple task power counters](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/task.c)
