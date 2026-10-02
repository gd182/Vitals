//
//  AppDelegater.swift
//  Vitals
//
//  Created by Алексей on 6/17/26.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItemCPU: NSStatusItem?
    var statusItemRAM: NSStatusItem?
    var statusItemGPU: NSStatusItem?
    var vm = SystemViewModel()
    var popoverCPU = NSPopover()
    var popoverRAM = NSPopover()
    var popoverGPU = NSPopover()

    var langManager = LanguageManager()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        popoverCPU.delegate = self
        popoverRAM.delegate = self
        popoverGPU.delegate = self
        popoverCPU.contentSize = NSSize(width: 250, height: 250)
        popoverCPU.behavior = .transient
        statusItemCPU = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let cpuIconView = NSHostingView(rootView: MenuBarLabelView(metrics: vm.menuBarMetrics, module: "CPU"))
        cpuIconView.frame = NSRect(x: 0, y: 0, width: 50, height: 22)
        statusItemCPU?.button?.addSubview(cpuIconView)
        statusItemCPU?.button?.frame = cpuIconView.frame
        statusItemCPU?.button?.action = #selector(toggleCPUPopover)
        statusItemCPU?.button?.target = self
        popoverRAM.contentSize = NSSize(width: 250, height: 250)
        popoverRAM.behavior = .transient
        statusItemRAM = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let ramIconView = NSHostingView(rootView: MenuBarLabelView(metrics: vm.menuBarMetrics, module: "RAM"))
        ramIconView.frame = NSRect(x: 0, y: 0, width: 50, height: 22)
        statusItemRAM?.button?.addSubview(ramIconView)
        statusItemRAM?.button?.frame = ramIconView.frame
        statusItemRAM?.button?.action = #selector(toggleRAMPopover)
        statusItemRAM?.button?.target = self
        popoverGPU.contentSize = NSSize(width: 250, height: 250)
        popoverGPU.behavior = .transient
        statusItemGPU = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let gpuIconView = NSHostingView(rootView: MenuBarLabelView(metrics: vm.menuBarMetrics, module: "GPU"))
        gpuIconView.frame = NSRect(x: 0, y: 0, width: 50, height: 22)
        statusItemGPU?.button?.addSubview(gpuIconView)
        statusItemGPU?.button?.frame = gpuIconView.frame
        statusItemGPU?.button?.action = #selector(toggleGPUPopover)
        statusItemGPU?.button?.target = self
    }
    
    @objc func toggleCPUPopover()
    {
        if popoverCPU.isShown {
            popoverCPU.performClose(nil)
        } else {
            popoverCPU.contentViewController = NSHostingController(rootView:
                LocalizedRoot(langManager: self.langManager) {
                    CPUView()
                        .environmentObject(self.vm)
                        .environmentObject(self.langManager)
                }
            )
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
            popoverRAM.contentViewController = NSHostingController(rootView:
                LocalizedRoot(langManager: self.langManager) {
                    RAMView()
                        .environmentObject(self.vm)
                        .environmentObject(self.langManager)
                }
            )
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
            popoverGPU.contentViewController = NSHostingController(rootView:
                LocalizedRoot(langManager: self.langManager) {
                    GPUView()
                        .environmentObject(self.vm)
                        .environmentObject(self.langManager)
                }
            )
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
