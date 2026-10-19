import ctypes
import argparse
import importlib.util
import json
import os
import select
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "test" / "profile_process.py"
spec = importlib.util.spec_from_file_location("profile_process", SCRIPT)
monitor = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = monitor
spec.loader.exec_module(monitor)


def snapshot(at, cpu_ns, memory=1024, identity=(123, b"test")):
    return monitor.Snapshot(at, identity, {"resident_bytes": memory}, {
        "user_ns": cpu_ns, "system_ns": 0, "context_switches": 0,
    })


class CalculationTests(unittest.TestCase):
    def test_default_reports_are_beside_script(self):
        prefix = monitor.default_output()
        self.assertEqual(prefix.parent, SCRIPT.parent / "tests_results")
        self.assertTrue(prefix.name.startswith("vitals-"))

    def test_mach_timebase_conversion(self):
        self.assertEqual(monitor.ticks_to_ns(24_000_000, 125, 3), 1_000_000_000)
        self.assertEqual(monitor.ticks_to_ns(1_000_000_000, 1, 1), 1_000_000_000)

    def test_cpu_is_one_core_percent_and_not_clamped(self):
        row = monitor.difference(snapshot(1, 0), snapshot(3, 3_000_000_000))
        self.assertEqual(row["cpu_percent"], 150)
        self.assertEqual(row["user_cpu_percent"], 150)
        self.assertEqual(row["system_cpu_percent"], 0)

    def test_counter_wrap_and_rates(self):
        before = snapshot(1, 0)
        before.counters["context_switches"] = 2 ** 32 - 2
        after = snapshot(3, 0)
        after.counters["context_switches"] = 4
        row = monitor.difference(before, after)
        self.assertEqual(row["context_switches_delta"], 6)
        self.assertEqual(row["context_switches_per_s"], 3)

    def test_reused_pid_and_bad_clock_are_rejected(self):
        with self.assertRaises(monitor.MonitorError):
            monitor.difference(snapshot(1, 0), snapshot(2, 0, identity=(456, b"new")))
        with self.assertRaises(monitor.MonitorError):
            monitor.difference(snapshot(1, 0), snapshot(1, 0))
        with self.assertRaises(monitor.MonitorError):
            monitor.difference(snapshot(1, 100), snapshot(2, 50))

    def test_sleep_or_wall_clock_jump_stops_measurement(self):
        before, after = snapshot(1, 0), snapshot(6, 100)
        before.wall_at = 1000
        for wall_at in (1600, 900):
            after.wall_at = wall_at
            with self.assertRaisesRegex(monitor.MonitorError, "Clock discontinuity"):
                monitor.difference(before, after)
        after.wall_at = 1005.01
        self.assertEqual(monitor.difference(before, after)["interval_s"], 5)

    def test_summary_weights_actual_intervals(self):
        first, second, third = snapshot(0, 0), snapshot(1, 100_000_000), snapshot(4, 700_000_000)
        summary = monitor.Summary(first)
        summary.add(monitor.difference(first, second), second)
        summary.add(monitor.difference(second, third), third)
        report = summary.report()
        self.assertEqual(report["metrics"]["cpu_percent"]["mean"], 17.5)
        self.assertEqual(report["counter_deltas"]["user_ns"], 700_000_000)

    def test_empty_and_memory_summary(self):
        first, second = snapshot(1, 0, memory=8192), snapshot(2, 0, memory=4096)
        summary = monitor.Summary(first)
        self.assertEqual(summary.report()["samples"], 0)
        summary.add(monitor.difference(first, second), second)
        self.assertEqual(summary.report()["memory"]["resident_bytes"]["change_bytes"], -4096)
        self.assertIn("4,096 B (0.004 MiB)", monitor.memory(4096))

    def test_invalid_numbers(self):
        for value in ("0", "-1", "nan", "inf"):
            with self.assertRaises(argparse.ArgumentTypeError):
                monitor.positive(value)


@unittest.skipUnless(sys.platform == "darwin", "macOS libproc integration")
class NativeTests(unittest.TestCase):
    def test_ctrl_c_keeps_partial_report(self):
        with tempfile.TemporaryDirectory() as directory:
            prefix = Path(directory) / "interrupted"
            command = [sys.executable, str(SCRIPT), "--pid", str(os.getpid()),
                       "--duration", "120", "--interval", "0.05", "--output", str(prefix)]
            with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as child:
                try:
                    received = b""
                    deadline = time.monotonic() + 10
                    while b"\n[1]" not in received:
                        remaining = deadline - time.monotonic()
                        self.assertGreater(remaining, 0, received.decode(errors="replace"))
                        readable, _, _ = select.select([child.stdout], [], [], remaining)
                        self.assertTrue(readable, "Timed out waiting for the first sample")
                        chunk = os.read(child.stdout.fileno(), 4096)
                        self.assertTrue(chunk, "Monitor exited before the first sample")
                        received += chunk
                    child.send_signal(signal.SIGINT)
                    _, errors = child.communicate(timeout=10)
                    self.assertEqual(child.returncode, 130, errors.decode())
                    report = json.loads(Path(str(prefix) + ".json").read_text())
                    self.assertEqual(report["status"], "interrupted")
                    self.assertGreaterEqual(report["samples"], 1)
                finally:
                    if child.poll() is None:
                        child.kill()
                        child.wait()

    def test_native_layout_and_cpu_units(self):
        self.assertEqual(ctypes.sizeof(monitor.RUsageV2), 160)
        self.assertEqual(ctypes.sizeof(monitor.TaskInfo), 96)
        process = monitor.MacProcess(os.getpid())
        first = process.snapshot()
        start_cpu = time.process_time_ns()
        while time.process_time_ns() - start_cpu < 30_000_000:
            pass
        second = process.snapshot()
        elapsed_cpu = time.process_time_ns() - start_cpu
        measured_cpu = sum(second.counters[k] - first.counters[k] for k in ("user_ns", "system_ns"))
        self.assertLess(abs(measured_cpu - elapsed_cpu), 10_000_000)
        self.assertGreater(second.gauges["resident_bytes"], 0)
        self.assertGreater(second.gauges["footprint_bytes"], 0)
        self.assertGreaterEqual(second.gauges["threads"], 1)
        self.assertEqual(first.identity, second.identity)

    def test_cli_outputs_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            prefix = Path(directory) / "nested" / "measurement"
            command = [sys.executable, str(SCRIPT), "--pid", str(os.getpid()),
                       "--duration", "0.15", "--interval", "0.05", "--output", str(prefix)]
            result = subprocess.run(command, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
            report_path = Path(str(prefix) + ".json")
            original = report_path.read_text()
            report = json.loads(original)
            self.assertEqual(report["status"], "completed")
            self.assertGreaterEqual(report["samples"], 1)
            self.assertGreater(report["metrics"]["resident_bytes"]["mean"], 0)
            result = subprocess.run(command, capture_output=True, text=True, timeout=15)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(report_path.read_text(), original)

    def test_missing_process_and_invalid_cli(self):
        for arguments in (["--pid", "-1"], ["--duration", "nan"],
                          ["--name", "Vitals.profile-test.nonexistent"]):
            result = subprocess.run([sys.executable, str(SCRIPT), *arguments],
                                    capture_output=True, text=True, timeout=15)
            self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
