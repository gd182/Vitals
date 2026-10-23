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
        print("Menu-bar preferences and accessibility fallback checks passed")
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
