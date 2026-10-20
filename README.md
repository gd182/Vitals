# Vitals

A macOS menu-bar monitor for CPU, GPU and memory usage, activity history,
temperature readings and resource-intensive processes.

**English** | [Русский](README.ru.md)

## Screenshots

<p>
  <img src="docs/images/gpu-compact.png" width="300" alt="Compact GPU panel" />
  <img src="docs/images/appearance.png" width="600" alt="Appearance settings" />
</p>

## Features

- CPU usage, available temperature readings and top processes.
- GPU activity and memory readings where supported by the driver.
- RAM usage and top memory-consuming processes.
- Activity charts with timestamps, configurable thresholds and colors.
- Customizable menu items, panel sections, layouts and refresh intervals.
- Light, dark and system themes; English, Russian and German localization.
- Optional launch at login and daily GitHub release checks.

Update downloads and installation are manual. Pre-release versions are optional.

## Requirements and Limitations

- **macOS 14.6+**, Intel or Apple Silicon.
- To build: **Xcode 26.2+**, Swift 6.2+ and the macOS SDK. No third-party dependencies.
- Temperature and GPU counters depend on hardware and drivers. Unavailable
  temperatures show `N/A`; unsupported GPU counters may show zero.
- Apple Silicon uses shared CPU/GPU memory; GPU memory is not dedicated VRAM.
- Process visibility depends on macOS permissions; multi-core processes can exceed 100% CPU.
- RAM percentage is memory usage, not macOS memory pressure.
- Not every supported Mac model has been tested on real hardware.

## Build

```sh
git clone https://github.com/gd182/Vitals.git
cd Vitals
open Vitals.xcodeproj
```

Select the `Vitals` scheme and run. The app appears in the menu bar, not the Dock.

For a Universal development build:

```sh
xcodebuild -project Vitals.xcodeproj -scheme Vitals -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath /tmp/VitalsBuild \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
```

Output: `/tmp/VitalsBuild/Build/Products/Release/Vitals.app`.
This command does not perform Developer ID signing or notarization.
See the [release checklist](docs/RELEASING.md) for distribution.

## Development

<p>
  <a href="https://www.swift.org/"><img src="https://raw.githubusercontent.com/danielcranney/profileme-dev/main/public/icons/skills/swift-colored.svg" width="36" height="36" alt="Swift" title="Swift" /></a>
  <a href="https://isocpp.org/"><img src="https://raw.githubusercontent.com/danielcranney/profileme-dev/main/public/icons/skills/cplusplus-colored.svg" width="36" height="36" alt="C++" title="C++" /></a>
</p>

SwiftUI and AppKit provide the interface. C++20 collectors connect through an
Objective-C++ bridge; Swift helpers read SMC temperatures. Settings use
UserDefaults, and chart history is bounded and kept in memory.

```sh
bash Tests/run-checks.sh
```

See [test instructions](Tests/README.md), the
[performance guide](docs/PERFORMANCE.md) and [contribution guide](CONTRIBUTING.md).
Remove credentials and private process details before sharing diagnostic data.

## License

MIT - see [LICENSE](LICENSE).
