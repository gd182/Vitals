//
//  AppDelegate.swift
//  Vitals
//
//  Created by Алексей on 6/17/26.
//

import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    var statusItemCPU: NSStatusItem?
    var statusItemRAM: NSStatusItem?
    var statusItemGPU: NSStatusItem?
    var vm = SystemViewModel()
    var popoverCPU = NSPopover()
    var popoverRAM = NSPopover()
    var popoverGPU = NSPopover()
    private lazy var cpuResizeAnimator = PopoverResizeAnimator(popover: popoverCPU)
    private lazy var ramResizeAnimator = PopoverResizeAnimator(popover: popoverRAM)
    private var subscriptions: [MenuBarModule: AnyCancellable] = [:]

    var langManager = LanguageManager()
    let updateChecker = UpdateChecker(
        currentVersion: Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String,
        fetchReleases: {
            try await GitHubReleaseService().fetchReleases()
        }
    )
    private lazy var automaticUpdateScheduler = AutomaticUpdateScheduler(
        checker: updateChecker,
        preferences: UpdatePreferences()
    )
    private var defaultsObserver: AnyCancellable?
    private var menuBarPreferences: MenuBarPreferences?
    private var setupObserver: AnyCancellable?
    private var lifecycleObservers = Set<AnyCancellable>()
    private let workspaceNotificationCenter: NotificationCenter
    private(set) var setupWindow: NSWindow?
    private var updatePreferencesSnapshot: (
        enabled: Bool,
        prereleases: Bool
    )?

    override convenience init() {
        self.init(workspaceNotificationCenter: NSWorkspace.shared.notificationCenter)
    }

    init(workspaceNotificationCenter: NotificationCenter) {
        self.workspaceNotificationCenter = workspaceNotificationCenter
        super.init()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        popoverCPU.delegate = self
        popoverRAM.delegate = self
        popoverGPU.delegate = self
        popoverCPU.contentSize = NSSize(width: 360, height: 540)
        popoverCPU.behavior = .transient
        popoverRAM.contentSize = NSSize(width: 360, height: 540)
        popoverRAM.behavior = .transient
        popoverGPU.contentSize = NSSize(width: 360, height: 540)
        popoverGPU.behavior = .transient
        updateMenuBar()
        defaultsObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBar()
                self?.updateAutomaticUpdatePreferences()
            }
        setupObserver = NotificationCenter.default.publisher(for: .init("VitalsShowSetup"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.showSetup() }
        workspaceNotificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
                self?.closePopovers()
            }
            .store(in: &lifecycleObservers)
        workspaceNotificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.closePopovers() }
            .store(in: &lifecycleObservers)
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self, let window = notification.object as? NSWindow else { return }
                // Popover windows can also be titled; identify them by ownership.
                var ancestor: NSWindow? = window
                while let current = ancestor {
                    if [self.popoverCPU, self.popoverRAM, self.popoverGPU].contains(where: {
                        $0.isShown && $0.contentViewController?.view.window === current
                    }) { return }
                    ancestor = current.parent
                }
                if window.styleMask.contains(.titled), !(window is NSPanel) {
                    self.closePopovers()
                }
            }
            .store(in: &lifecycleObservers)
        if !UserDefaults.standard.bool(forKey: "hasCompletedSetup") {
            showSetup()
        }

        workspaceNotificationCenter.publisher(
            for: NSWorkspace.didWakeNotification
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.refreshAutomaticUpdates()
        }
        .store(in: &lifecycleObservers)

        updateChecker.$state
            .map { state -> Bool in
                if case .checking = state {
                    return true
                }
                return false
            }
            .removeDuplicates()
            .dropFirst()
            .filter { !$0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAutomaticUpdates()
            }
            .store(in: &lifecycleObservers)

        updateAutomaticUpdatePreferences()
    }

    func showSetup() {
        closePopovers()
        if let setupWindow {
            NSApp.activate(ignoringOtherApps: true)
            setupWindow.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 540),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Vitals"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let content = SetupView { [weak self] in
            UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
            self?.setupWindow?.close()
        }
        .environmentObject(langManager)
        window.contentViewController = NSHostingController(rootView:
            LocalizedRoot(langManager: langManager) {
                content
            }
        )
        setupWindow = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === setupWindow else { return }
        setupWindow = nil
    }

    private func updateMenuBar() {
        let preferences = MenuBarPreferences()
        guard preferences != menuBarPreferences else { return }
        menuBarPreferences = preferences
        updateStatusItem(&statusItemCPU, enabled: preferences.cpu, module: MenuBarModule.cpu,
                         action: #selector(toggleCPUPopover), popover: popoverCPU)
        updateStatusItem(&statusItemRAM, enabled: preferences.ram, module: MenuBarModule.ram,
                         action: #selector(toggleRAMPopover), popover: popoverRAM)
        updateStatusItem(&statusItemGPU, enabled: preferences.gpu, module: MenuBarModule.gpu,
                         action: #selector(toggleGPUPopover), popover: popoverGPU)
    }

    private func updateStatusItem(_ item: inout NSStatusItem?, enabled: Bool, module: MenuBarModule,
                                  action: Selector, popover: NSPopover) {
        if !enabled {
            popover.close()
            subscriptions[module]?.cancel()
            subscriptions[module] = nil
            if let existing = item { NSStatusBar.system.removeStatusItem(existing) }
            item = nil
            return
        }
        guard item == nil else { return }
        let statusItem = NSStatusBar.system.statusItem(withLength: 36)
        let metric: MenuBarMetric
        switch module {
            case .cpu:
                metric = vm.menuBarMetrics.cpu
            case .ram:
                metric = vm.menuBarMetrics.ram
            case .gpu:
                metric = vm.menuBarMetrics.gpu
        }

        guard let button = statusItem.button else {
            NSStatusBar.system.removeStatusItem(statusItem)
            return
        }

        button.action = action
        button.target = self
        button.toolTip = module.title
        button.imagePosition = .imageOnly

        subscriptions[module] = metric.$value
            .sink { [weak button] percent in
                guard let button else {
                    return
                }

                button.image = MenuBarImageRenderer.render(
                    module: module,
                    percent: percent
                )
                button.setAccessibilityLabel(
                    "\(module.title) \(percent)%"
                )
            }
        item = statusItem
    }
    
    @objc func toggleCPUPopover()
    {
        if popoverCPU.isShown {
            popoverCPU.performClose(nil)
        } else {
            closePopovers(except: popoverCPU)
            let controller = NSHostingController(rootView:
                LocalizedRoot(langManager: self.langManager) {
                    CPUView(onSizeChange: { [weak animator = self.cpuResizeAnimator] size in
                        animator?.resize(to: size)
                    })
                        .environmentObject(self.vm)
                        .environmentObject(self.langManager)
                }
            )
            // The resize animator is the only owner of CPU/RAM popover size updates.
            controller.sizingOptions = []
            popoverCPU.contentViewController = controller
            if let button = statusItemCPU?.button {
                vm.setPopoverVisible(true, module: "CPU")
                popoverCPU.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                if let popoverWindow = popoverCPU.contentViewController?.view.window {
                    popoverWindow.level = .statusBar
                    popoverWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                }
            }
        }
    }
    
    @objc func toggleRAMPopover()
    {
        if popoverRAM.isShown {
            popoverRAM.performClose(nil)
        } else {
            closePopovers(except: popoverRAM)
            let controller = NSHostingController(rootView:
                LocalizedRoot(langManager: self.langManager) {
                    RAMView(onSizeChange: { [weak animator = self.ramResizeAnimator] size in
                        animator?.resize(to: size)
                    })
                        .environmentObject(self.vm)
                        .environmentObject(self.langManager)
                }
            )
            controller.sizingOptions = []
            popoverRAM.contentViewController = controller
            if let button = statusItemRAM?.button {
                vm.setPopoverVisible(true, module: "RAM")
                popoverRAM.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                if let popoverWindow = popoverRAM.contentViewController?.view.window {
                    popoverWindow.level = .statusBar
                    popoverWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                }
            }
        }
    }
    
    @objc func toggleGPUPopover()
    {
        if popoverGPU.isShown {
            popoverGPU.performClose(nil)
        } else {
            closePopovers(except: popoverGPU)
            let controller = NSHostingController(rootView:
                LocalizedRoot(langManager: self.langManager) {
                    GPUView(onSizeChange: { [weak popover = self.popoverGPU] size in
                        popover?.contentSize = size
                    })
                        .environmentObject(self.vm)
                        .environmentObject(self.langManager)
                }
            )
            controller.sizingOptions = [.preferredContentSize]
            popoverGPU.contentViewController = controller
            if let button = statusItemGPU?.button {
                vm.setPopoverVisible(true, module: "GPU")
                popoverGPU.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                if let popoverWindow = popoverGPU.contentViewController?.view.window {
                    popoverWindow.level = .statusBar
                    popoverWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                }
            }
        }
    }

    private func closePopovers(except retainedPopover: NSPopover? = nil) {
        for popover in [popoverCPU, popoverRAM, popoverGPU] where popover !== retainedPopover {
            if popover.isShown { popover.close() }
        }
    }

    func popoverWillClose(_ notification: Notification) {
        if notification.object as? NSPopover === popoverCPU { cpuResizeAnimator.cancel() }
        if notification.object as? NSPopover === popoverRAM { ramResizeAnimator.cancel() }
    }

    func popoverDidClose(_ notification: Notification) {
        guard let popover = notification.object as? NSPopover else { return }
        let module = popover === popoverCPU ? "CPU" : popover === popoverRAM ? "RAM" : "GPU"
        vm.setPopoverVisible(false, module: module)
        // Tear down after AppKit finishes handling the close notification.
        DispatchQueue.main.async { [weak popover] in
            guard let popover, !popover.isShown else { return }
            popover.contentViewController = nil
        }
    }

    private func refreshAutomaticUpdates() {
        automaticUpdateScheduler.refresh(
            includePrereleases: UserDefaults.standard.bool(
                forKey: "includePrereleaseUpdates"
            )
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        cpuResizeAnimator.cancel()
        ramResizeAnimator.cancel()
        automaticUpdateScheduler.stop()
    }

    private func updateAutomaticUpdatePreferences() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: "automaticUpdateChecks")
        let prereleases = defaults.bool(forKey: "includePrereleaseUpdates")

        if let snapshot = updatePreferencesSnapshot,
        snapshot.enabled == enabled,
        snapshot.prereleases == prereleases {
            return
        }

        updatePreferencesSnapshot = (
            enabled: enabled,
            prereleases: prereleases
        )
        refreshAutomaticUpdates()
    }
}
