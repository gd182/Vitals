# Contributing

Small, focused changes are welcome. Discuss large features in an issue first.
English and Russian issue reports are welcome.

## Setup

Use macOS 14.6+ and full Xcode 26.2+ (Swift 6.2+). Open `Vitals.xcodeproj`
and select the shared `Vitals` scheme. No application dependencies are required.

## Before A Pull Request

1. Run `bash Tests/run-checks.sh` and the Universal build from the README.
2. For UI changes, run `bash Tests/run-checks.sh --ui` on a logged-in desktop
   and manually check scrolling, settings, transient-popover focus and text fit.
3. Check both light and dark themes and English/Russian/German labels.
4. Keep monitoring work off the main thread, avoid extra timers and unbounded
   histories, and preserve on-demand process/sensor sampling.
5. Do not assume an Apple Silicon sensor key or GPU counter works on Intel,
   every chip generation, or a virtual machine. Report actual tested hardware.
6. Keep commits logically focused and leave unrelated formatting/settings alone.

Build output and generated UI snapshots belong in temporary directories.
Do not commit credentials, signing identities, serial numbers or private logs.

## Bug Reports

Include app version/commit, Mac model, chip/GPU, macOS version, reproduction
steps and relevant preferences. Redact private process names and file paths.
Missing sensor readings may be a hardware limitation rather than an interface bug.

## License

Contributions are provided under the project's [MIT license](LICENSE).
