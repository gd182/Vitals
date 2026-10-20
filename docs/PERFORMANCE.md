# Performance Measurements

## Repeatable Setup

- Use a Release build without the debugger and quit other copies of Vitals.
- Record the commit, Mac model, architecture, macOS/Xcode versions and power mode.
- Keep refresh intervals, visible modules, panel layout and other workloads fixed.
- Disable automatic update checks when measuring monitoring overhead.
- Allow 60 seconds of warmup, measure for 120 seconds and repeat three times.
- Keep the Mac awake; measure sleep/wake separately.

Compare closed panels, each open panel, recovery after closing and repeated
open/close cycles. Use the same process when checking cumulative memory growth.

## Process Report

From the repository root, with exactly one Vitals process running:

```sh
caffeinate -i python3 test/profile_process.py --warmup 60 --duration 120 \
  --label background
```

Requires macOS and Python 3.9+, without third-party packages. Use `--pid` when
multiple copies are running. `--interval` controls sampling (default: 5 seconds).
The script reads libproc directly; it does not start Vitals or stress the machine.

CSV/JSON reports go to the ignored `test/tests_results/` directory. `--output`
sets another filename prefix. Existing files are not overwritten. Ctrl+C saves
partial results; process identity changes, access errors and significant clock
discontinuities stop the measurement. Do not treat partial runs as full baselines.

## Interpretation

- CPU: 100% means one logical CPU; Mach ticks are converted using the host timebase.
- Memory: compare physical footprint and RSS separately; virtual size is not RAM usage.
- Wakeups: idle and interrupt counters are distinct and must not be added together.
- JSON means are interval-weighted; memory peaks between samples can be missed.
- Stable post-close memory does not prove that repeated openings never retain objects.
- Lower CPU alone does not establish lower energy consumption.

The tool does not measure GPU load, network traffic, watts or allocation stacks.
Keep raw reports and Instruments traces local; they may contain private data.

## Instruments

Confirm the executable path and PID before recording. Use Time Profiler for CPU
call stacks and Allocations for retained memory. Compare equal selected durations
and distinguish inclusive Weight from Self Weight. Keep instrumented recordings
separate from uninstrumented process reports.

Retain optimizations only after functional checks and repeatable measurements.
Changing languages or language standards is not itself evidence of a speedup.

## References

- [Apple: Performance and metrics](https://developer.apple.com/documentation/xcode/performance-and-metrics)
- [Apple: Gathering information about memory use](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use)
- [Apple libproc interfaces](https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/wrappers/libproc/libproc.h)
