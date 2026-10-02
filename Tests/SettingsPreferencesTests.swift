import Foundation

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
        print("Menu-bar preferences and accessibility fallback checks passed")
    }
}
