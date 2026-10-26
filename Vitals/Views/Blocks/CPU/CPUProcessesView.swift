import SwiftUI

struct CPUProcessesView: View {
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("cpuProcessVisibleRows") private var visibleRows = ProcessListLayout.defaultVisibleRows

    var body: some View {
        ProcessListView(state: vm.cpuProcessState, processes: vm.topProcessesByCPU, visibleRows: visibleRows) { process in
            String(format: "%.1f%%", process.value)
        }
        .onAppear { vm.isMonitoringProcessesCPU = true }
        .onDisappear { vm.isMonitoringProcessesCPU = false }
    }
}
