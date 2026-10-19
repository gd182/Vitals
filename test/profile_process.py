#!/usr/bin/env python3
"""Sample a macOS process through libproc; no third-party packages required."""

import argparse
import csv
import ctypes as C
import datetime as dt
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time
from contextlib import ExitStack
from dataclasses import dataclass


class MonitorError(Exception):
    pass


# Layouts from macOS SDK sys/resource.h and sys/proc_info.h.
class RUsageV2(C.Structure):
    _fields_ = [("uuid", C.c_ubyte * 16)] + [
        (name, C.c_uint64) for name in (
            "user_ticks", "system_ticks", "idle_wakeups", "interrupt_wakeups",
            "pageins", "wired_bytes", "resident_bytes", "footprint_bytes",
            "start", "exit", "child_user", "child_system", "child_idle",
            "child_interrupt", "child_pageins", "child_elapsed",
            "read_bytes", "written_bytes",
        )
    ]


class TaskInfo(C.Structure):
    _fields_ = [(name, C.c_uint64) for name in (
        "virtual_bytes", "resident_bytes", "user", "system",
        "threads_user", "threads_system",
    )] + [(name, C.c_int32) for name in (
        "policy", "faults", "pageins", "cow_faults", "messages_sent",
        "messages_received", "mach_calls", "unix_calls", "context_switches",
        "threads", "running_threads", "priority",
    )]


class Timebase(C.Structure):
    _fields_ = [("numer", C.c_uint32), ("denom", C.c_uint32)]


def ticks_to_ns(ticks, numer, denom):
    return ticks * numer // denom


@dataclass
class Snapshot:
    at: float
    identity: tuple
    gauges: dict
    counters: dict
    wall_at: float = None


class MacProcess:
    def __init__(self, pid):
        if sys.platform != "darwin":
            raise MonitorError("This tool requires macOS.")
        self.pid = pid
        self.lib = C.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        self.lib.proc_pid_rusage.argtypes = [C.c_int, C.c_int, C.c_void_p]
        self.lib.proc_pid_rusage.restype = C.c_int
        self.lib.proc_pidinfo.argtypes = [
            C.c_int, C.c_int, C.c_uint64, C.c_void_p, C.c_int,
        ]
        self.lib.proc_pidinfo.restype = C.c_int
        system = C.CDLL("/usr/lib/libSystem.B.dylib")
        system.mach_timebase_info.argtypes = [C.POINTER(Timebase)]
        system.mach_timebase_info.restype = C.c_int
        self.timebase = Timebase()
        if system.mach_timebase_info(C.byref(self.timebase)) != 0 or not self.timebase.denom:
            raise MonitorError("Cannot read Mach timebase.")
        self.task_info_available = None

    def snapshot(self):
        usage = RUsageV2()
        before = time.monotonic()
        C.set_errno(0)
        if self.lib.proc_pid_rusage(self.pid, 2, C.byref(usage)) != 0:
            code = C.get_errno()
            raise MonitorError(
                f"Cannot read PID {self.pid}: {os.strerror(code)}. "
                "The process may have exited or access may be denied."
            )
        if usage.exit:
            raise MonitorError(f"PID {self.pid} has exited.")
        task = TaskInfo()
        size = self.lib.proc_pidinfo(self.pid, 4, 0, C.byref(task), C.sizeof(task))
        at = (before + time.monotonic()) / 2
        available = size == C.sizeof(task)
        if self.task_info_available is not None and available != self.task_info_available:
            raise MonitorError("Task-info availability changed; start a new measurement.")
        self.task_info_available = available
        gauges = {"footprint_bytes": usage.footprint_bytes, "wired_bytes": usage.wired_bytes}
        counters = {name: getattr(usage, name) for name in (
            "idle_wakeups", "interrupt_wakeups",
            "pageins", "read_bytes", "written_bytes",
        )}
        for kind in ("user", "system"):
            counters[kind + "_ns"] = ticks_to_ns(
                getattr(usage, kind + "_ticks"), self.timebase.numer, self.timebase.denom,
            )
        if available:
            gauges.update({name: getattr(task, name) for name in (
                "resident_bytes", "virtual_bytes", "threads", "running_threads",
            )})
            counters.update({name: C.c_uint32(getattr(task, name)).value for name in (
                "faults", "cow_faults", "context_switches", "mach_calls", "unix_calls",
            )})
        return Snapshot(at, (usage.start, bytes(usage.uuid)), gauges, counters, time.time())


COUNTERS_32 = {"faults", "cow_faults", "context_switches", "mach_calls", "unix_calls"}


def difference(previous, current):
    if current.identity != previous.identity:
        raise MonitorError("PID was reused or the executable changed; stopping.")
    elapsed = current.at - previous.at
    if elapsed <= 0:
        raise MonitorError("Sampling clock did not advance.")
    if previous.wall_at is not None and current.wall_at is not None:
        wall_elapsed = current.wall_at - previous.wall_at
        if abs(wall_elapsed - elapsed) > max(2.0, elapsed * 0.1):
            raise MonitorError(
                "Clock discontinuity detected (possible sleep or wall-clock adjustment). "
                "Partial results are saved; repeat the steady-state measurement while awake."
            )
    deltas = {}
    for name, value in current.counters.items():
        delta = value - previous.counters[name]
        if name in COUNTERS_32:
            delta %= 2 ** 32
        elif delta < 0:
            raise MonitorError(f"Counter {name} decreased; start a new measurement.")
        deltas[name] = delta
    row = {
        "timestamp": dt.datetime.now().astimezone().isoformat(timespec="milliseconds"),
        "interval_s": elapsed,
        "cpu_percent": (deltas["user_ns"] + deltas["system_ns"]) / elapsed / 1e7,
        "user_cpu_percent": deltas["user_ns"] / elapsed / 1e7,
        "system_cpu_percent": deltas["system_ns"] / elapsed / 1e7,
        **current.gauges,
    }
    for name, value in deltas.items():
        row[name + "_delta"] = value
        if name not in {"user_ns", "system_ns"}:
            row[name + "_per_s"] = value / elapsed
    return row


class Summary:
    def __init__(self, baseline):
        self.baseline = baseline
        self.last = baseline
        self.count = 0
        self.elapsed = 0.0
        self.metrics = {}
        self.totals = {}

    def add(self, row, snapshot):
        self.count += 1
        self.elapsed += row["interval_s"]
        self.last = snapshot
        for name, value in row.items():
            if name in {"timestamp", "interval_s"} or name.endswith("_delta"):
                continue
            stat = self.metrics.setdefault(name, {"min": value, "max": value, "weighted": 0.0})
            stat["min"] = min(stat["min"], value)
            stat["max"] = max(stat["max"], value)
            stat["weighted"] += value * row["interval_s"]
        for name in snapshot.counters:
            self.totals[name] = self.totals.get(name, 0) + row[name + "_delta"]

    def report(self):
        return {
            "samples": self.count,
            "elapsed_s": self.elapsed,
            "metrics": {name: {
                "min": stat["min"], "max": stat["max"],
                "mean": stat["weighted"] / self.elapsed,
            } for name, stat in self.metrics.items()},
            "counter_deltas": self.totals,
            "memory": {name: {
                "start_bytes": value, "end_bytes": self.last.gauges[name],
                "change_bytes": self.last.gauges[name] - value,
            } for name, value in self.baseline.gauges.items() if name.endswith("_bytes")},
        }


def memory(value):
    return "N/A" if value is None else f"{value:,.0f} B ({value / 1048576:.3f} MiB)"


def show_row(index, row):
    def rate(name):
        value = row.get(name + "_per_s")
        return "N/A" if value is None else f"{value:.2f}"

    print(f"\n[{index}] {row['timestamp']}  interval={row['interval_s']:.3f}s", flush=True)
    print(f"  CPU {row['cpu_percent']:.3f}% "
          f"(user {row['user_cpu_percent']:.3f}%, system {row['system_cpu_percent']:.3f}%)")
    print(f"  RSS {memory(row.get('resident_bytes'))}")
    print(f"  Physical footprint {memory(row['footprint_bytes'])}; wired {memory(row['wired_bytes'])}")
    print(f"  Virtual address space {memory(row.get('virtual_bytes'))} (not RAM usage)")
    print(f"  Threads {row.get('threads', 'N/A')}; running {row.get('running_threads', 'N/A')}")
    print(f"  Wakeups/s: package-idle {rate('idle_wakeups')}, interrupt {rate('interrupt_wakeups')}")
    print(f"  Context switches/s {rate('context_switches')}; "
          f"faults/s {rate('faults')}; page-ins/s {rate('pageins')}")
    print(f"  Mach calls/s {rate('mach_calls')}; Unix calls/s {rate('unix_calls')}; "
          f"COW faults/s {rate('cow_faults')}")
    print(f"  Disk I/O: read {rate('read_bytes')} B/s, write {rate('written_bytes')} B/s", flush=True)


def show_summary(report):
    print(f"\nSUMMARY: {report['samples']} intervals, {report['elapsed_s']:.3f}s")
    for name in ("cpu_percent", "user_cpu_percent", "system_cpu_percent",
                 "resident_bytes", "footprint_bytes", "threads",
                 "idle_wakeups_per_s", "interrupt_wakeups_per_s",
                 "context_switches_per_s", "read_bytes_per_s", "written_bytes_per_s"):
        stat = report["metrics"].get(name)
        if stat is None:
            continue
        formatter = memory if name.endswith("_bytes") else lambda n: f"{n:.3f}"
        print(f"  {name}: mean {formatter(stat['mean'])}; "
              f"min {formatter(stat['min'])}; max {formatter(stat['max'])}")
    for name, item in report["memory"].items():
        print(f"  {name}: start {memory(item['start_bytes'])}; "
              f"end {memory(item['end_bytes'])}; change {item['change_bytes']:+,} B")
    print("  Counter totals: " + json.dumps(report["counter_deltas"], sort_keys=True))


def positive(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("must be a finite positive number")
    return number


def sysctl_value(name):
    result = subprocess.run(
        ["/usr/sbin/sysctl", "-n", name], capture_output=True, text=True, check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def default_output():
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    return Path(__file__).resolve().parent / "tests_results" / f"vitals-{stamp}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    target = parser.add_mutually_exclusive_group()
    target.add_argument("--pid", type=int)
    target.add_argument("--name", help="exact process name (default: Vitals)")
    parser.add_argument("--interval", type=positive, default=5.0, help="seconds (default: 5)")
    parser.add_argument("--duration", type=positive, default=120.0, help="seconds (default: 120)")
    parser.add_argument("--warmup", type=float, default=0.0, help="seconds before the baseline")
    parser.add_argument("--label", default="unspecified", help="scenario and settings description")
    parser.add_argument(
        "--output", type=Path, default=default_output(),
        help="report prefix (default: test/tests_results/vitals-TIMESTAMP); no overwrite",
    )
    args = parser.parse_args()
    if not math.isfinite(args.warmup) or args.warmup < 0:
        parser.error("--warmup must be finite and nonnegative")
    if sys.platform != "darwin":
        parser.error("this tool requires macOS")
    if args.pid is not None and args.pid <= 0:
        parser.error("--pid must be positive")

    summary = None
    status = "completed"
    code = 0
    with ExitStack() as stack:
        try:
            pid = args.pid
            if pid is None:
                found = subprocess.run(
                    ["/usr/bin/pgrep", "-x", "--", re.escape(args.name or "Vitals")],
                    capture_output=True, text=True, check=False,
                )
                if found.returncode not in (0, 1):
                    raise MonitorError(found.stderr.strip() or "Process lookup failed.")
                pids = found.stdout.split()
                if len(pids) != 1:
                    raise MonitorError(f"Expected one process, found {len(pids)}. Use --pid explicitly.")
                pid = int(pids[0])
            process = MacProcess(pid)
            initial = process.snapshot()
            metadata = {
                "pid": pid, "label": args.label, "macos": platform.mac_ver()[0],
                "observer_arch": platform.machine(), "logical_cpus": os.cpu_count(),
                "cpu_model": sysctl_value("machdep.cpu.brand_string"),
                "machine_model": sysctl_value("hw.model"),
                "system_memory_bytes": sysctl_value("hw.memsize"),
                "python": platform.python_version(),
                "started_at": dt.datetime.now().astimezone().isoformat(),
                "interval_s": args.interval, "requested_duration_s": args.duration,
                "warmup_s": args.warmup, "cpu_basis": "100% = one logical CPU",
                "memory_units": "bytes; displayed MiB = bytes / 1048576",
                "source": "libproc RUSAGE_INFO_V2 and PROC_PIDTASKINFO",
                "mach_timebase": {"numer": process.timebase.numer, "denom": process.timebase.denom},
            }
            csv_file = json_file = None
            if args.output:
                args.output.parent.mkdir(parents=True, exist_ok=True)
                csv_file = stack.enter_context(Path(str(args.output) + ".csv").open("x", newline=""))
                json_file = stack.enter_context(Path(str(args.output) + ".json").open("x"))
            print(json.dumps(metadata, indent=2))
            print("RSS and footprint differ. Wakeup counters are distinct; do not sum them.")
            print("Disk I/O is kernel-accounted storage traffic, not every read/write call.")
            print("GPU usage, network bytes, watts and allocation stacks are not measured.")
            if not process.task_info_available:
                print("Task info unavailable: RSS, virtual size, threads and task event rates are N/A.")
            print("Ctrl+C saves a partial report. Sampling overhead is not subtracted.", flush=True)
            if args.warmup:
                print(f"Warmup: {args.warmup:g}s", flush=True)
                time.sleep(args.warmup)
            baseline = process.snapshot()
            if initial.identity != baseline.identity:
                raise MonitorError("Process identity changed during warmup.")
            summary = Summary(baseline)
            previous = baseline
            deadline = baseline.at + args.duration
            writer = None
            while previous.at < deadline:
                target_time = min(previous.at + args.interval, deadline)
                time.sleep(max(0, target_time - time.monotonic()))
                current = process.snapshot()
                row = difference(previous, current)
                summary.add(row, current)
                if csv_file:
                    if writer is None:
                        writer = csv.DictWriter(csv_file, fieldnames=list(row))
                        writer.writeheader()
                    writer.writerow(row)
                    csv_file.flush()
                show_row(summary.count, row)
                previous = current
        except KeyboardInterrupt:
            status, code = "interrupted", 130
        except (MonitorError, OSError, ValueError) as error:
            status, code = str(error), 1
            print(f"Error: {error}", file=sys.stderr)
        if summary is not None:
            report = {"metadata": metadata, "status": status, **summary.report()}
            print(f"\nMeasurement status: {status}")
            show_summary(report)
            if json_file:
                json.dump(report, json_file, indent=2, allow_nan=False)
                json_file.write("\n")
            if args.output:
                print(f"Reports: {args.output}.csv and {args.output}.json")
    return code


if __name__ == "__main__":
    sys.exit(main())
