import Foundation

nonisolated struct MenuBarPreferences: Equatable {
    let cpu: Bool
    let ram: Bool
    let gpu: Bool

    init(defaults: UserDefaults = .standard) {
        let cpu = defaults.object(forKey: "menuBarCPU") as? Bool ?? true
        let ram = defaults.object(forKey: "menuBarRAM") as? Bool ?? true
        let gpu = defaults.object(forKey: "menuBarGPU") as? Bool ?? true
        // Keep the app reachable even if stored preferences are invalid.
        self.cpu = cpu || (!ram && !gpu)
        self.ram = ram
        self.gpu = gpu
    }
}
