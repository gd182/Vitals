import SwiftUI

struct RAMProcessesView: View {
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("ramProcessVisibleRows") private var visibleRows = ProcessListLayout.defaultVisibleRows

    var body: some View {
        ProcessListView(state: vm.ramProcessState, processes: vm.topProcessesByRAM, visibleRows: visibleRows) { process in
            Format.formatBytes(UInt64(max(0, process.value)))
        }
        .onAppear { vm.isMonitoringProcessesRAM = true }
        .onDisappear { vm.isMonitoringProcessesRAM = false }
    }
}
