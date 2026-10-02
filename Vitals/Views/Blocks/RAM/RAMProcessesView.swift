import SwiftUI

struct RAMProcessesView: View {
    @EnvironmentObject var vm: SystemViewModel

    var body: some View {
        VStack {
            Text("block_processes")
            ForEach(vm.topProcessesByRAM) { process in
                ProcessRow(process: process, value: Format.formatBytes(UInt64(max(0, process.value))))
            }
            .padding(1)
        }
        .padding(10)
        .onAppear { vm.isMonitoringProcessesRAM = true }
        .onDisappear { vm.isMonitoringProcessesRAM = false }
    }
}
