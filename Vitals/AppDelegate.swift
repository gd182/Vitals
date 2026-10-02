//
//  AppDelegater.swift
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

    var langManager = LanguageManager()
    private var defaultsObserver: AnyCancellable?
    private var menuBarPreferences: MenuBarPreferences?
    private var setupObserver: AnyCancellable?
    private var lifecycleObservers = Set<AnyCancellable>()
    private let workspaceNotificationCenter: NotificationCenter
    private(set) var setupWindow: NSWindow?

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
            .sink { [weak self] _ in self?.updateMenuBar() }
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
        updateStatusItem(&statusItemCPU, enabled: preferences.cpu, module: "CPU",
                         action: #selector(toggleCPUPopover), popover: popoverCPU)
        updateStatusItem(&statusItemRAM, enabled: preferences.ram, module: "RAM",
                         action: #selector(toggleRAMPopover), popover: popoverRAM)
        updateStatusItem(&statusItemGPU, enabled: preferences.gpu, module: "GPU",
                         action: #selector(toggleGPUPopover), popover: popoverGPU)
    }

    private func updateStatusItem(_ item: inout NSStatusItem?, enabled: Bool, module: String,
                                  action: Selector, popover: NSPopover) {
        if !enabled {
            popover.close()
            if let existing = item { NSStatusBar.system.removeStatusItem(existing) }
            item = nil
            return
        }
        guard item == nil else { return }
        let statusItem = NSStatusBar.system.statusItem(withLength: 36)
        let label = NSHostingView(rootView: MenuBarLabelView(metrics: vm.menuBarMetrics, module: module))
        label.frame = NSRect(x: 0, y: 0, width: 36, height: 22)
        label.autoresizingMask = [.width, .height]
        statusItem.button?.addSubview(label)
        statusItem.button?.action = action
        statusItem.button?.target = self
        statusItem.button?.toolTip = module
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
                    CPUView(onSizeChange: { [weak popover = self.popoverCPU] size in
                        popover?.contentSize = size
                    })
                        .environmentObject(self.vm)
                        .environmentObject(self.langManager)
                }
            )
            controller.sizingOptions = [.preferredContentSize]
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
                    RAMView(onSizeChange: { [weak popover = self.popoverRAM] size in
                        popover?.contentSize = size
                    })
                        .environmentObject(self.vm)
                        .environmentObject(self.langManager)
                }
            )
            controller.sizingOptions = [.preferredContentSize]
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
}
