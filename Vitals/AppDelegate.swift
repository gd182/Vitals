//
//  AppDelegater.swift
//  Vitals
//
//  Created by Алексей on 6/17/26.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItemCPU: NSStatusItem?
    var statusItemRAM: NSStatusItem?
    var statusItemGPU: NSStatusItem?
    var vm = SystemViewModel()
    var popoverCPU = NSPopover()
    var popoverRAM = NSPopover()
    var popoverGPU = NSPopover()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        popoverCPU.contentViewController = NSHostingController(rootView: CPUView().environmentObject(vm))
        popoverCPU.contentSize = NSSize(width: 250, height: 250)
        popoverCPU.behavior = .transient
        statusItemCPU = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        var cpuIconView = NSHostingView(rootView: MenuBarLabelView(vm: vm, module: "CPU"))
        cpuIconView.frame = NSRect(x: 0, y: 0, width: 50, height: 22)
        statusItemCPU?.button?.addSubview(cpuIconView)
        statusItemCPU?.button?.frame = cpuIconView.frame
        statusItemCPU?.button?.action = #selector(toggleCPUPopover)
        statusItemCPU?.button?.target = self
        
        popoverRAM.contentViewController = NSHostingController(rootView: RAMView().environmentObject(vm))
        popoverRAM.contentSize = NSSize(width: 250, height: 250)
        popoverRAM.behavior = .transient
        statusItemRAM = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let ramIconView = NSHostingView(rootView: MenuBarLabelView(vm: vm, module: "RAM"))
        ramIconView.frame = NSRect(x: 0, y: 0, width: 50, height: 22)
        statusItemRAM?.button?.addSubview(ramIconView)
        statusItemRAM?.button?.frame = ramIconView.frame
        statusItemRAM?.button?.action = #selector(toggleRAMPopover)
        statusItemRAM?.button?.target = self
        
        popoverGPU.contentViewController = NSHostingController(rootView: GPUView().environmentObject(vm))
        popoverGPU.contentSize = NSSize(width: 250, height: 250)
        popoverGPU.behavior = .transient
        statusItemGPU = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let gpuIconView = NSHostingView(rootView: MenuBarLabelView(vm: vm, module: "GPU"))
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
            if let button = statusItemCPU?.button {
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
            if let button = statusItemRAM?.button {
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
            if let button = statusItemGPU?.button {
                popoverGPU.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                if let popoverWindow = popoverGPU.contentViewController?.view.window {
                    popoverWindow.level = .statusBar
                    popoverWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                }
            }
        }
    }

}
