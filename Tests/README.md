# Application Checks

Run from a logged-in macOS desktop with Xcode's command-line tools selected:

```sh
bash Tests/run-checks.sh
```

The native checks sample real CPU and memory counters, check that Mach send-right
references do not grow, and verify process CPU percentages against a busy thread.
Process enumeration requires an unrestricted local process, not a coding sandbox.
The Swift checks use a fake monitor and volatile preferences, without modifying
the app's settings. They cover background/foreground cadence, on-demand process
and temperature polling, stale results after closing, slow samples, deallocation,
threshold defaults, and bounded timestamped history. Swift assertions must stay
enabled; the script deliberately uses `-Onone` for these checks.

The sensor checks exercise Intel Core/Xeon names, the configured M1-M5 families,
unrecognized names and future generation names, without opening the SMC device.
An absent temperature sample must clear the previous value instead of displaying
zero or a stale temperature.

Color checks cover custom thresholds, exact threshold boundaries, cubic curve
crossings, single-sample peaks and wide transitions that must not overlap.
The color-test executable accepts an optional PNG path to render a preview with
the actual Canvas graph and circular indicators.

Settings checks cover all eight combinations of menu modules, including the
CPU fallback when all stored toggles are disabled. They use volatile defaults.
Layout checks use a separate disposable defaults suite for reordering, block
visibility, reconciliation and reset, leaving application preferences untouched.

Login-item checks inject a fake service and cover registration, approval,
external status changes and errors. They never register a real login item.
Verify actual launch after login manually using an installed, signed app.

Build a Universal binary to validate both architectures:

```sh
xcodebuild -project Vitals.xcodeproj -scheme Vitals -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath /tmp/VitalsUniversalBuild \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
lipo -archs /tmp/VitalsUniversalBuild/Build/Products/Release/Vitals.app/Contents/MacOS/Vitals
```

Cross-compilation checks both code paths; real Intel hardware is still needed
to verify its SMC sensors and GPU driver statistics. Unsupported sensor data is
not guaranteed to become available through fallback probing. The deployment
target remains macOS 14.6 or newer.

To include a Release build and real AppKit popover lifecycle checks:

```sh
bash Tests/run-checks.sh --ui
```

The UI test temporarily shows CPU/RAM/GPU popovers and terminates its own copy.
It also checks module removal and restoration, setup-window close/reopen, and
watches automatic closing on Space changes and application deactivation,
checks that switching modules closes the previous panel, and
writes settings snapshots in English, Russian and German to the temporary
directory. Launch-argument overrides avoid changing saved module preferences
or marking the real app's setup complete.
Workspace notifications are injected so real desktop activity cannot interrupt
programmatically opened panels; actual app/Space switching remains a manual check.
Panel snapshots cover CPU, RAM, GPU, and changing the GPU panel width and theme
while it is open. Chart previews use the same Canvas renderer as live charts.
Compact panels use content-driven height capped by available screen space;
oversized content remains scrollable. Color checks include RGB persistence
conversion and invalid-value fallback. UI snapshots also cover custom colors
and the separate appearance tabs.
It disables animations and uses application-defined popover behavior because programmatic opening does
not establish the focus of a real status-button click. It exercises the normal
close delegate and reopening, but does not simulate outside mouse clicks.
Real sleep/wake, animated closing, and transient-popover focus should also be checked manually.
Temporary build artifacts remain in the printed directory for inspection.
