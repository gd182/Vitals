import AppKit
import SwiftUI

@MainActor
final class ProcessResizeProbe: ObservableObject {
    @Published var state = ProcessListState.loading
    @Published var processes: [ProcessUsage] = []
}

struct ProcessResizeProbeView: View {
    @ObservedObject var probe: ProcessResizeProbe
    let format: (ProcessUsage) -> String
    let onSizeChange: (CGSize) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text("Processes").frame(height: 36)
            ProcessListView(state: probe.state, processes: probe.processes, visibleRows: 5, formattedValue: format)
        }
        .padding(12)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: onSizeChange)
    }
}

@main
struct PopoverSmokeTests {
    @MainActor static func checkMetricHelpGeometry() {
        for topic in MetricHelpTopic.allCases {
            for language in ["en", "ru", "de"] {
                for scheme in [ColorScheme.light, .dark] {
                    let view = NSHostingView(rootView:
                        MetricHelpView(topic: topic)
                            .environment(\.locale, Locale(identifier: language))
                            .preferredColorScheme(scheme)
                    )
                    let size = view.fittingSize
                    assert(abs(size.width - 300) < 1 && size.height > 60 && size.height < 400)
                }
            }
        }
        print("RAM/GPU explanation geometry checks passed in RU/EN/DE and both themes")
    }

    @MainActor static func click(_ point: NSPoint, in view: NSView) {
        let window = view.window!
        let location = view.convert(point, to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)!
            NSApp.postEvent(event, atStart: false)
        }
    }

    @MainActor static func helpInteractionSteps(
        for topics: [MetricHelpTopic], in popover: NSPopover, anchor: @escaping () -> NSView
    ) -> [(Double, @MainActor () -> Void)] {
        var steps: [(Double, @MainActor () -> Void)] = []
        for topic in topics {
            var knownWindows = Set<Int>()
            var helpWindow: NSWindow?
            steps.append((0.2, {
                let controller = NSHostingController(rootView:
                    MetricHelpButton(topic: topic).frame(width: 80, height: 80)
                )
                controller.sizingOptions = [.preferredContentSize]
                popover.animates = false
                popover.contentViewController = controller
                let button = anchor()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }))
            steps.append((0.2, {
                knownWindows = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
                let view = popover.contentViewController!.view
                click(NSPoint(x: view.bounds.midX, y: view.bounds.midY), in: view)
            }))
            steps.append((0.4, {
                assert(popover.isShown)
                helpWindow = NSApp.windows.first { $0.isVisible && !knownWindows.contains($0.windowNumber) }
                guard let window = helpWindow else { fatalError("Help did not open for \(topic.titleKey)") }
                snapshot(window, name: "help-\(topic.titleKey)")
                // AppKit's popover chrome surrounds the 300-point SwiftUI content.
                let bounds = window.contentView!.bounds
                assert(bounds.width >= 300 && bounds.width <= 340 && bounds.height < 400)
                if topic == .memoryPressure || topic == .gpuNeuralEngine {
                    let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                        context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                        isARepeat: false, keyCode: 53)!
                    if !window.performKeyEquivalent(with: escape) { NSApp.sendEvent(escape) }
                } else {
                    let view = window.contentView!
                    let inset = (view.bounds.width - 300) / 2 + 28
                    let y = view.isFlipped ? view.bounds.minY + inset : view.bounds.maxY - inset
                    click(NSPoint(x: view.bounds.maxX - inset, y: y), in: view)
                }
            }))
            steps.append((0.3, {
                assert(helpWindow?.isVisible == false)
                assert(popover.isShown, "Closing an explanation must not close its parent panel")
                popover.close()
                popover.contentViewController = nil
            }))
        }
        return steps
    }

    @MainActor static func checkProcessListGeometry() {
        let processes = (1...10).map { index in
            ProcessUsage(id: Int32(index), name: "A long process name \(index)", value: Double(index))
        }
        for visibleRows in [3, 5, 10, 0, 99] {
            for width: CGFloat in [328, 336, 388, 396] {
                for language in ["en", "ru", "de"] {
                    let scenarios: [(ProcessListState, [ProcessUsage])] = [
                        (.inactive, []), (.loading, []), (.ready, []),
                        (.ready, Array(processes.prefix(1))),
                        (.ready, Array(processes.prefix(3))), (.ready, processes)
                    ]
                    var heights: [CGFloat] = []
                    for (state, entries) in scenarios {
                        let view = NSHostingView(rootView:
                            ProcessListView(state: state, processes: entries, visibleRows: visibleRows) { _ in "999.99 GB" }
                                .frame(width: width)
                                .environment(\.locale, Locale(identifier: language))
                        )
                        let size = view.fittingSize
                        assert(abs(size.width - width) < 1)
                        assert(size.height >= 0 && size.height < 300)
                        heights.append(size.height)
                    }
                    assert(heights[0] < 1)
                    assert(heights.dropFirst().allSatisfy { $0 > 0 })
                    let rows = ProcessListLayout.validatedVisibleRows(visibleRows)
                    assert(heights[1] < heights[5] && heights[2] < heights[5])
                    assert(abs(heights[3] - ProcessRow.height) < 1)
                    assert(abs(heights[4] - (3 * ProcessRow.height + 2 * 4)) < 1)
                    assert(abs(heights[5] - (CGFloat(rows) * ProcessRow.height + CGFloat(rows - 1) * 4)) < 1)
                }
            }
        }
        print("Dynamic process list loading, empty, short and capped geometry checks passed")
    }

    @MainActor static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        for child in view.subviews {
            if let scrollView = firstScrollView(in: child) { return scrollView }
        }
        return nil
    }

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
        checkProcessListGeometry()
        checkMetricHelpGeometry()
        let workspaceEvents = NotificationCenter()
        let delegate = AppDelegate(workspaceNotificationCenter: workspaceEvents)
        overrideDefaults(["panelWidth": 360.0, "processUpdateInterval": 0.5, "panelCompact": true, "panelSectionTitles": true,
                         "cpuProcessVisibleRows": 5, "ramProcessVisibleRows": 5])
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
        let resizePopover = NSPopover()
        resizePopover.behavior = .applicationDefined
        let resizeAnimator = PopoverResizeAnimator(popover: resizePopover, reduceMotion: { false })
        let resizeProbe = ProcessResizeProbe()
        var resizeFrames: [NSRect] = []
        var resizeSamplingTask: Task<Void, Never>?
        var resizeInitialSize = NSSize.zero
        for format in ["99.9%", "999.9 GB"] {
            steps.append((0.3, {
                resizeProbe.state = .loading
                resizeProbe.processes = []
                resizePopover.animates = false
                let controller = NSHostingController(rootView:
                    ProcessResizeProbeView(probe: resizeProbe, format: { _ in format }) { size in
                        resizeAnimator.resize(to: size)
                    }
                )
                controller.sizingOptions = []
                resizePopover.contentViewController = controller
                let button = delegate.statusItemCPU!.button!
                resizePopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }))
            steps.append((0.3, {
                assert(resizePopover.isShown)
                resizeInitialSize = resizePopover.contentSize
                resizeFrames = [resizePopover.contentViewController!.view.window!.frame]
                snapshot(resizePopover.contentViewController!.view.window!, name: "process-resize-loading")
                resizePopover.animates = true
                resizeSamplingTask = Task { @MainActor in
                    while !Task.isCancelled {
                        if let frame = resizePopover.contentViewController?.view.window?.frame {
                            resizeFrames.append(frame)
                        }
                        try? await Task.sleep(for: .milliseconds(8))
                    }
                }
                resizeProbe.processes = (1...10).map {
                    ProcessUsage(id: Int32($0), name: "Process \($0)", value: Double($0))
                }
                resizeProbe.state = .ready
            }))
            steps.append((0.6, {
                resizeSamplingTask?.cancel()
                resizeSamplingTask = nil
                assert(resizePopover.contentSize.height > resizeInitialSize.height + 50)
                assert(abs(resizePopover.contentSize.width - resizeInitialSize.width) < 1)
                let initialFrame = resizeFrames[0]
                assert(resizeFrames.allSatisfy { abs($0.maxY - initialFrame.maxY) < 2 },
                       "Process popover moved its top edge during expansion")
                let finalHeight = resizeFrames.last!.height
                let intermediate = resizeFrames.filter {
                    $0.height > initialFrame.height + 1 && $0.height < finalHeight - 1
                }.count
                assert(intermediate >= 3, "Expected actual intermediate window sizes, not a single resize")
                assert(zip(resizeFrames, resizeFrames.dropFirst()).allSatisfy { $1.height >= $0.height - 1 },
                       "Process popover changed direction during expansion")
                assert(!resizeAnimator.isAnimating)
                print("Process popover controlled expansion (\(format)): \(intermediate) intermediate sizes; top edge stable")
                snapshot(resizePopover.contentViewController!.view.window!, name: "process-resize-ready")
                let scrollView = firstScrollView(in: resizePopover.contentViewController!.view)!
                let document = scrollView.documentView!
                assert(document.bounds.height > scrollView.contentView.bounds.height + 50,
                       "The remaining process rows must be scrollable, not discarded")
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: document.bounds.maxY - scrollView.contentView.bounds.height))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                assert(scrollView.contentView.bounds.minY > 0)
                snapshot(resizePopover.contentViewController!.view.window!, name: "process-list-scrolled")
                resizeAnimator.cancel()
                resizePopover.animates = false
                resizePopover.close()
                resizePopover.contentViewController = nil
            }))
        }
        let helpPopover = NSPopover()
        helpPopover.behavior = .applicationDefined
        steps += helpInteractionSteps(for: MetricHelpTopic.allCases, in: helpPopover,
                                      anchor: { delegate.statusItemGPU!.button! })
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
        }))
        steps.append((0.2, { overrideDefaults(["panelSectionTitles": false]) }))
        steps.append((0.3, {
            snapshot(delegate.popoverGPU.contentViewController!.view.window!, name: "gpu-help-without-titles")
        }))
        steps.append((0.2, {
            overrideDefaults(["panelSectionTitles": true])
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
            let view = delegate.popoverCPU.contentViewController!.view
            assert(view.bounds.height > 0)
            assert(view.bounds.height <= 600)
            assert(abs(view.bounds.height - delegate.popoverCPU.contentSize.height) < 1)
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
                                .environmentObject(delegate.updateChecker)
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
                        .environmentObject(delegate.updateChecker)
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
