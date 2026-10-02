import SwiftUI

struct CPUProcessesView: View {
    @EnvironmentObject var vm: SystemViewModel

    var body: some View {
        VStack {
            ForEach(vm.topProcessesByCPU) { process in
                ProcessRow(process: process, value: String(format: "%.1f%%", process.value))
            }
        }
        .padding(10)
        .onAppear { vm.isMonitoringProcessesCPU = true }
        .onDisappear { vm.isMonitoringProcessesCPU = false }
    }
}
