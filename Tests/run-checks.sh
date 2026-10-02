#!/bin/bash
set -eu

cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/vitals-checks.XXXXXX")

xcrun clang++ -std=c++17 -O2 -I Vitals/Core Tests/CoreMetricsTests.cpp \
    Vitals/Core/CPUStats.cpp Vitals/Core/MemoryStats.cpp \
    Vitals/Core/GPUStats.cpp Vitals/Core/ProcessStats.cpp \
    -framework IOKit -framework CoreFoundation -o "$check_dir/core-tests"
"$check_dir/core-tests"

xcrun swiftc -swift-version 5 -Onone -module-cache-path "$check_dir/swift-cache" \
    Tests/MonitoringTests.swift Vitals/Models/MonitoringPreferences.swift \
    Vitals/Models/ProcessUsage.swift Vitals/Models/UsageColorScale.swift Vitals/Utils/CircularBuffer.swift \
    Vitals/Utils/HistoryData.swift Vitals/ViewModels/SystemViewModel.swift \
    -o "$check_dir/monitoring-tests"
"$check_dir/monitoring-tests"

xcrun swiftc -swift-version 5 -Onone -module-cache-path "$check_dir/swift-cache" \
    Tests/SensorCompatibilityTests.swift Vitals/Core/SensorReader.swift Vitals/Core/SMCReader.swift \
    -o "$check_dir/sensor-tests"
"$check_dir/sensor-tests"

xcrun swiftc -swift-version 5 -Onone -module-cache-path "$check_dir/swift-cache" \
    Tests/ChartColorTests.swift Vitals/Models/UsageColorScale.swift Vitals/Models/UsagePalette.swift \
    Vitals/Utils/CircularBuffer.swift Vitals/Utils/HistoryData.swift \
    Vitals/Views/Components/GradientLineView.swift Vitals/Views/Components/CircularIndicator.swift \
    -o "$check_dir/color-tests"
"$check_dir/color-tests"

xcrun swiftc -swift-version 5 -Onone -module-cache-path "$check_dir/swift-cache" \
    Tests/SettingsPreferencesTests.swift Vitals/Models/MenuBarPreferences.swift Vitals/Models/DashboardConfig.swift \
    -o "$check_dir/settings-tests"
"$check_dir/settings-tests"

xcrun swiftc -swift-version 5 -Onone -module-cache-path "$check_dir/swift-cache" \
    Tests/LoginItemTests.swift Vitals/Models/LoginItemSettings.swift \
    -o "$check_dir/login-tests"
"$check_dir/login-tests"

if [[ "${1:-}" == "--ui" ]]; then
    machine_arch=$(uname -m)
    xcodebuild -quiet -project Vitals.xcodeproj -scheme Vitals -configuration Release \
        -destination "platform=macOS,arch=$machine_arch" \
        -derivedDataPath "$check_dir/build" CODE_SIGNING_ALLOWED=NO build
    cp -R "$check_dir/build/Build/Products/Release/Vitals.app" "$check_dir/Smoke.app"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier org.vitals.Smoke.$RANDOM" "$check_dir/Smoke.app/Contents/Info.plist"
    swift_sources=()
    while IFS= read -r source; do
        swift_sources+=("$source")
    done < <(find Vitals -type f -name '*.swift' ! -name 'VitalsApp.swift')
    object_dir="$check_dir/build/Build/Intermediates.noindex/Vitals.build/Release/Vitals.build/Objects-normal/$machine_arch"
    native_objects=()
    for name in SystemMonitor CPUStats MemoryStats GPUStats ProcessStats; do
        native_objects+=("$object_dir/$name.o")
    done
    xcrun swiftc -swift-version 5 -Onone -target "$machine_arch-apple-macos14.6" \
        -default-isolation MainActor -module-cache-path "$check_dir/swift-cache" \
        -import-objc-header Vitals/Bridge/SystemMonitor.h \
        Tests/PopoverSmokeTests.swift "${swift_sources[@]}" "${native_objects[@]}" \
        -Xlinker -lc++ -framework IOKit -framework CoreFoundation \
        -o "$check_dir/Smoke.app/Contents/MacOS/Vitals"
    "$check_dir/Smoke.app/Contents/MacOS/Vitals" -updateInterval 0.5 -backgroundUpdateInterval 3 -hasCompletedSetup NO -menuBarCPU YES -menuBarRAM YES -menuBarGPU YES
fi

echo "Checks completed. Build artifacts: $check_dir"
