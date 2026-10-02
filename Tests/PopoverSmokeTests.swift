import AppKit
import SwiftUI

@main
struct PopoverSmokeTests {
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
        let delegate = AppDelegate()
        app.delegate = delegate
        var steps: [(Double, @MainActor () -> Void)] = [(0.3, {
            assert(delegate.statusItemCPU != nil)
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
        steps.append((0.3, { delegate.toggleRAMPopover() }))
        steps.append((0.7, {
            assert(delegate.vm.isMonitoringProcessesRAM)
            delegate.popoverRAM.close()
        }))
        steps.append((0.5, {
            assert(delegate.popoverRAM.contentViewController == nil)
            assert(!delegate.vm.isMonitoringProcessesRAM)
            delegate.toggleGPUPopover()
        }))
        steps.append((0.5, {
            assert(delegate.popoverGPU.isShown)
            delegate.popoverGPU.close()
        }))
        steps.append((0.5, { assert(delegate.popoverGPU.contentViewController == nil) }))
        schedule(steps)
        app.run()
    }
}
