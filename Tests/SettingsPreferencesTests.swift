import Foundation
import SwiftUI

@MainActor
private struct RAMIndicatorPreferencesProbe {
    @AppStorage private var storedStyle: RAMIndicatorStyle

    init(defaults: UserDefaults) {
        _storedStyle = AppStorage(wrappedValue: .ring, "ramIndicatorStyle", store: defaults)
    }

    var style: RAMIndicatorStyle {
        get { storedStyle }
        nonmutating set { storedStyle = newValue }
    }
}

@MainActor
private struct ProcessRowsPreferencesProbe {
    @AppStorage private var storedRows: Int

    init(key: String, defaults: UserDefaults) {
        _storedRows = AppStorage(wrappedValue: ProcessListLayout.defaultVisibleRows, key, store: defaults)
    }

    var rows: Int {
        get { ProcessListLayout.validatedVisibleRows(storedRows) }
        nonmutating set { storedRows = ProcessListLayout.validatedVisibleRows(newValue) }
    }
}

@main
struct SettingsPreferencesTests {
    @MainActor static func main() {
        let suite = "VitalsSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for mask in 0..<8 {
            defaults.setVolatileDomain([
                "menuBarCPU": mask & 1 != 0,
                "menuBarRAM": mask & 2 != 0,
                "menuBarGPU": mask & 4 != 0
            ], forName: UserDefaults.argumentDomain)
            let preferences = MenuBarPreferences(defaults: defaults)
            assert(preferences.cpu == (mask & 1 != 0 || mask == 0))
            assert(preferences.ram == (mask & 2 != 0))
            assert(preferences.gpu == (mask & 4 != 0))
            assert(preferences.cpu || preferences.ram || preferences.gpu)
        }
        defaults.setVolatileDomain([:], forName: UserDefaults.argumentDomain)
        let preferences = MenuBarPreferences(defaults: defaults)
        assert(preferences.cpu && preferences.ram && preferences.gpu)
        let layout = DashboardConfig(namespace: "TEST", defaults: defaults)
        layout.reconcile(ids: ["a", "b", "c"])
        layout.moveDown(id: "a")
        assert(layout.order == ["b", "a", "c"])
        layout.setVisible(id: "b", false)
        layout.reconcile(ids: ["a", "b", "d"])
        assert(layout.order == ["b", "a", "d"] && !layout.isVisible(id: "b"))
        layout.reset(ids: ["a", "b", "d"])
        assert(layout.order == ["a", "b", "d"] && layout.isVisible(id: "b"))
        testRAMIndicatorStyle()
        testProcessRows()
        print("Menu-bar preferences and accessibility fallback checks passed")
    }

    @MainActor private static func testProcessRows() {
        let suite = "VitalsProcessRowsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cpu = ProcessRowsPreferencesProbe(key: "cpuProcessVisibleRows", defaults: defaults)
        let ram = ProcessRowsPreferencesProbe(key: "ramProcessVisibleRows", defaults: defaults)
        assert(cpu.rows == 5 && ram.rows == 5)
        for rows in ProcessListLayout.visibleRowRange {
            cpu.rows = rows
            assert(defaults.integer(forKey: "cpuProcessVisibleRows") == rows)
            assert(ProcessRowsPreferencesProbe(key: "cpuProcessVisibleRows", defaults: defaults).rows == rows)
            assert(ram.rows == 5)
        }
        cpu.rows = 3
        ram.rows = 10
        for invalid: Any in [-1, 0, 2, 11, Int.max, "invalid"] {
            defaults.set(invalid, forKey: "ramProcessVisibleRows")
            assert(ProcessRowsPreferencesProbe(key: "ramProcessVisibleRows", defaults: defaults).rows == 5)
            assert(cpu.rows == 3)
        }
        ram.rows = 8
        defaults.set("value", forKey: "ramIndicatorStyle")
        cpu.rows = ProcessListLayout.defaultVisibleRows
        assert(cpu.rows == 5 && ram.rows == 8)
        ram.rows = ProcessListLayout.defaultVisibleRows
        assert(cpu.rows == 5 && ram.rows == 5)
        assert(defaults.string(forKey: "ramIndicatorStyle") == "value")
        print("Process row limits, persistence, invalid values and independent resets passed")
    }

    @MainActor private static func testRAMIndicatorStyle() {
        let suite = "VitalsRAMIndicatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        assert(RAMIndicatorPreferencesProbe(defaults: defaults).style == .ring)
        for style in [RAMIndicatorStyle.ring, .value] {
            let writer = RAMIndicatorPreferencesProbe(defaults: defaults)
            writer.style = style
            assert(defaults.string(forKey: "ramIndicatorStyle") == style.rawValue)
            assert(RAMIndicatorPreferencesProbe(defaults: defaults).style == style)
        }
        for invalid: Any in ["future-mode", "", 1] {
            defaults.set(invalid, forKey: "ramIndicatorStyle")
            assert(RAMIndicatorPreferencesProbe(defaults: defaults).style == .ring)
        }
        let reset = RAMIndicatorPreferencesProbe(defaults: defaults)
        reset.style = .ring
        assert(defaults.string(forKey: "ramIndicatorStyle") == "ring")
        assert(RAMIndicatorPreferencesProbe(defaults: defaults).style == .ring)
        print("RAM indicator persistence, unknown value and reset checks passed")
    }
}
