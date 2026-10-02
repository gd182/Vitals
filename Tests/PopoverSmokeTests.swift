import AppKit
import SwiftUI

@main
struct PopoverSmokeTests {
    @MainActor static func overrideDefaults(_ values: [String: Any]) {
        var domain = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        domain.merge(values) { _, new in new }
        UserDefaults.standard.setVolatileDomain(domain, forName: UserDefaults.argumentDomain)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
    }

    @MainActor static func snapshot(_ window: NSWindow, name: String) {
        guard let view = window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            assertionFailure("Snapshot unavailable")
            return
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vitals-\(name).png")
        try! bitmap.representation(using: .png, properties: [:])!.write(to: path)
        print("UI snapshot: \(path.path)")
    }

    @MainActor static func schedule(_ steps: [(Double, @MainActor () -> Void)]) {
        guard let first = steps.first else {
            print("Popover open, close, reopen and teardown checks passed")
            NSApp.terminate(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + first.0) {
            first.1()
            schedule(Array(steps.dropFirst()))
        }
    }

    @MainActor static func main() {
        let app = NSApplication.shared
        let workspaceEvents = NotificationCenter()
        let delegate = AppDelegate(workspaceNotificationCenter: workspaceEvents)
        overrideDefaults(["panelWidth": 360.0, "processUpdateInterval": 0.5, "panelCompact": true, "panelSectionTitles": true])
        for (module, ids) in [
            "CPU": ["cpu_indicators", "cpu_details", "cpu_chart", "cpu_processes"],
            "RAM": ["ram_indicators", "ram_details", "ram_chart", "ram_processes"],
            "GPU": ["gpu_indicators", "gpu_details", "gpu_chart_utl", "gpu_chart_render", "gpu_chart_tiler", "gpu_chart_ane"]
        ] {
            overrideDefaults(["\(module).order": ids])
            for id in ids { overrideDefaults(["\(module).\(id).visible": true]) }
        }
        // Initialize the accessory delegate explicitly: headless/programmatic launch
        // can delay AppKit's launch callback past the first scheduled assertion.
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification, object: app))
        var steps: [(Double, @MainActor () -> Void)] = [(0.3, {
            assert(delegate.statusItemCPU != nil)
            assert(delegate.statusItemCPU?.length == 36)
            assert(delegate.statusItemRAM?.length == 36 && delegate.statusItemGPU?.length == 36)
            assert(delegate.setupWindow != nil)
            delegate.setupWindow?.close()
            assert(delegate.setupWindow == nil)
            assert(!UserDefaults.standard.bool(forKey: "hasCompletedSetup"))
            // Set behavior after applicationDidFinishLaunching has configured the popovers.
            delegate.popoverCPU.behavior = .applicationDefined
            delegate.popoverRAM.behavior = .applicationDefined
            delegate.popoverGPU.behavior = .applicationDefined
            // Animation completion depends on the host desktop's presentation cycle.
            delegate.popoverCPU.animates = false
            delegate.popoverRAM.animates = false
            delegate.popoverGPU.animates = false
        })]
        for _ in 0..<3 {
            steps.append((0.3, { delegate.toggleCPUPopover() }))
            steps.append((0.7, {
                assert(delegate.popoverCPU.isShown)
                snapshot(delegate.popoverCPU.contentViewController!.view.window!, name: "panel-cpu")
                assert(delegate.vm.isMonitoringProcessesCPU && delegate.vm.isMonitoringTemperature)
                // Direct close invokes the same delegate path used by an outside click.
                delegate.popoverCPU.close()
            }))
            steps.append((0.5, {
                assert(delegate.popoverCPU.contentViewController == nil)
                assert(!delegate.vm.isMonitoringProcessesCPU && !delegate.vm.isMonitoringTemperature)
                assert(delegate.vm.topProcessesByCPU.isEmpty)
            }))
        }
        steps.append((0.3, { delegate.toggleCPUPopover() }))
        steps.append((0.5, {
            assert(delegate.popoverCPU.isShown)
            delegate.toggleRAMPopover()
        }))
        steps.append((0.7, {
            assert(!delegate.popoverCPU.isShown && delegate.popoverCPU.contentViewController == nil)
            assert(delegate.vm.isMonitoringProcessesRAM)
            snapshot(delegate.popoverRAM.contentViewController!.view.window!, name: "panel-ram")
            workspaceEvents.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        }))
        steps.append((0.5, {
            assert(delegate.popoverRAM.contentViewController == nil)
            assert(!delegate.vm.isMonitoringProcessesRAM)
            delegate.toggleGPUPopover()
        }))
        steps.append((0.5, {
            assert(delegate.popoverGPU.isShown)
            snapshot(delegate.popoverGPU.contentViewController!.view.window!, name: "panel-gpu")
            assert(delegate.popoverGPU.contentViewController!.view.bounds.height <= 600)
            overrideDefaults(["panelWidth": 420.0, "appearance": "light"])
        }))
        steps.append((0.4, {
            assert(delegate.popoverGPU.contentViewController!.view.bounds.width == 420)
            snapshot(delegate.popoverGPU.contentViewController!.view.window!, name: "panel-gpu-wide")
            overrideDefaults(["panelWidth": 360.0, "appearance": "system"])
            delegate.popoverGPU.close()
        }))
        steps.append((0.3, {
            overrideDefaults(["usageColorNormal": 0x007AFF, "usageColorWarning": 0xFF9500, "usageColorCritical": 0xFF2D55])
            delegate.toggleCPUPopover()
        }))
        steps.append((1.2, {
            assert(delegate.popoverCPU.contentViewController!.view.bounds.height < 480)
            snapshot(delegate.popoverCPU.contentViewController!.view.window!, name: "panel-custom-colors")
            delegate.popoverCPU.close()
        }))
        steps.append((0.5, { assert(delegate.popoverGPU.contentViewController == nil) }))
        steps.append((0.2, { delegate.toggleCPUPopover() }))
        steps.append((0.5, {
            assert(delegate.popoverCPU.isShown)
            let otherApp = NSWorkspace.shared.runningApplications.first {
                $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }!
            workspaceEvents.post(name: NSWorkspace.didActivateApplicationNotification,
                object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: otherApp])
        }))
        steps.append((0.3, {
            assert(!delegate.popoverCPU.isShown && delegate.popoverCPU.contentViewController == nil)
            assert(!delegate.vm.isMonitoringProcessesCPU && !delegate.vm.isMonitoringTemperature)
        }))
        steps.append((0.2, { delegate.toggleGPUPopover() }))
        steps.append((0.5, {
            assert(delegate.popoverGPU.isShown)
            workspaceEvents.post(name: NSWorkspace.didActivateApplicationNotification,
                object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: NSRunningApplication.current])
            let panel = NSPanel(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
            NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: panel)
        }))
        steps.append((0.3, {
            assert(delegate.popoverGPU.isShown)
            delegate.showSetup()
        }))
        steps.append((0.3, {
            assert(!delegate.popoverGPU.isShown && delegate.popoverGPU.contentViewController == nil)
            delegate.setupWindow?.close()
        }))
        steps.append((0.2, {
            overrideDefaults(["menuBarRAM": false, "menuBarGPU": false])
        }))
        steps.append((0.3, {
            assert(delegate.statusItemCPU != nil)
            assert(delegate.statusItemRAM == nil && delegate.statusItemGPU == nil)
            overrideDefaults(["menuBarCPU": false])
        }))
        steps.append((0.3, {
            assert(delegate.statusItemCPU != nil)
            overrideDefaults(["menuBarCPU": true, "menuBarRAM": true, "menuBarGPU": true])
            delegate.showSetup()
        }))
        steps.append((0.5, {
            assert(delegate.statusItemRAM != nil && delegate.statusItemGPU != nil)
            assert(delegate.setupWindow != nil)
            snapshot(delegate.setupWindow!, name: "setup")
            delegate.setupWindow?.close()
            assert(delegate.setupWindow == nil)
            delegate.showSetup()
        }))
        steps.append((0.3, {
            assert(delegate.setupWindow != nil)
            delegate.setupWindow?.close()
        }))
        let settingsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
                                      styleMask: [.titled], backing: .buffered, defer: false)
        settingsWindow.isReleasedWhenClosed = false
        for theme in ["light", "dark"] {
            for language in ["en", "ru", "de"] {
                for section in SettingsView.Section.allCases {
                    steps.append((0.1, {
                        settingsWindow.contentViewController = NSHostingController(rootView:
                            SettingsView(initialSection: section)
                                .environmentObject(delegate.langManager)
                                .environment(\.locale, Locale(identifier: language))
                                .preferredColorScheme(theme == "dark" ? .dark : .light)
                        )
                        settingsWindow.center()
                        settingsWindow.makeKeyAndOrderFront(nil)
                    }))
                    steps.append((0.3, {
                        snapshot(settingsWindow, name: "settings-\(section.rawValue)-\(language)-\(theme)")
                    }))
                }
            }
        }
        steps.append((0.1, { settingsWindow.close() }))
        for tab in [1, 2] {
            steps.append((0.1, {
                settingsWindow.contentViewController = NSHostingController(rootView:
                    SettingsView(initialSection: .appearance, appearanceTab: tab)
                        .environmentObject(delegate.langManager)
                        .environment(\.locale, Locale(identifier: "ru"))
                )
                settingsWindow.makeKeyAndOrderFront(nil)
            }))
            steps.append((0.3, { snapshot(settingsWindow, name: "appearance-tab-\(tab)") }))
        }
        steps.append((0.1, { settingsWindow.close() }))
        schedule(steps)
        app.run()
    }
}
