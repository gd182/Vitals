# Application Checks

Run on macOS with Xcode's command-line tools selected:

```sh
bash Tests/run-checks.sh
```

The script runs native collector checks, standalone Swift checks with test
doubles, and the hostless Swift Testing target `VitalsTests`. Assertions must
remain enabled (`-Onone` for standalone Swift checks).

## UI Checks

From an active, logged-in macOS desktop:

```sh
bash Tests/run-checks.sh --ui
```

This also builds a Release app, exercises popovers and settings, and saves
screenshots. Temporary artifacts remain in the directory printed by the script.
Launch-argument overrides keep smoke-test settings separate from saved app settings.

## Coverage and Limits

- Native counters, process CPU accuracy and Mach port reference stability.
- Monitoring cadence, process loading, stale results, lifecycle and bounded history.
- Sensor classification, chart colors, layout preferences and login-item states.
- Release decoding, version selection and automatic-update scheduling with mocked networking.
- UI smoke checks cover panel switching, module visibility, settings and localization.

Real sensors, login registration, sleep/wake, outside-click dismissal and desktop
switching still require manual verification. Programmatic UI checks disable
animations and inject workspace notifications. Cross-compilation is not a
substitute for real Intel hardware testing.

## Editor Support

`MonitoringChecks` is a separate command-line target for `Tests/MonitoringTests.swift`
and its dependencies. Never add its fake collector to the app target. When changing
dependencies, keep its Sources phase aligned with `run-checks.sh`.

The shared `Vitals` scheme builds the helper for development/testing, but does not
run it or include it in the app archive. With `xcode-build-server`, build the
`Vitals` scheme in its configured DerivedData directory, then restart the Swift
language server if compiler settings remain stale.

## Profiling Tool

See the [measurement guide](../docs/PERFORMANCE.md) for `test/profile_process.py`.
Its tests run separately:

```sh
python3 -B -m unittest discover -s Tests -p test_profile_process.py -v
```
