import SwiftUI

struct CPUProcessesView: View {
    @EnvironmentObject var vm: SystemViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if vm.topProcessesByCPU.isEmpty {
                Text("panel_no_processes").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(vm.topProcessesByCPU) { process in
                ProcessRow(process: process, value: String(format: "%.1f%%", process.value))
            }
        }
        .monospacedDigit()
        .onAppear { vm.isMonitoringProcessesCPU = true }
        .onDisappear { vm.isMonitoringProcessesCPU = false }
    }
}
