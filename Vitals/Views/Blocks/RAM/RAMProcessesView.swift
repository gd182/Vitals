import SwiftUI

struct RAMProcessesView: View {
    @EnvironmentObject var vm: SystemViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if vm.topProcessesByRAM.isEmpty {
                Text("panel_no_processes").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(vm.topProcessesByRAM) { process in
                ProcessRow(process: process, value: Format.formatBytes(UInt64(max(0, process.value))))
            }
        }
        .monospacedDigit()
        .onAppear { vm.isMonitoringProcessesRAM = true }
        .onDisappear { vm.isMonitoringProcessesRAM = false }
    }
}
