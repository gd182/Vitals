import SwiftUI

struct CPUView: View {
    @EnvironmentObject var vm: SystemViewModel
    
    @StateObject var config = DashboardConfig(namespace: "CPU")
    
    let blocks: [DashboardBlock] = [
        DashboardBlock(id: "cpu_indicators", title: "Индикаторы", content: .cpuIndicators, hasSettings: false),
        DashboardBlock(id: "cpu_details", title: "Детали CPU", content: .cpuDetails, hasSettings: false),
        DashboardBlock(id: "cpu_chart", title: "График", content: .cpuChart(namespace: "chart_CPU"), hasSettings: true),
        DashboardBlock(id: "cpu_processes", title: "Процессы", content: .cpuProcesses, hasSettings: false),
    ]
    
    var body: some View {
        DashboardView(blocks: blocks, config: config)
        .onAppear {
            let currentIDs = blocks.map { $0.id }
            config.order = config.order.filter { currentIDs.contains($0) }
            let newIDs = currentIDs.filter { !config.order.contains($0) }
            config.order.append(contentsOf: newIDs)
            
            vm.isMonitoringProcessesCPU = true
        }
        .onDisappear {vm.isMonitoringProcessesCPU = false}
    }
}

#Preview {
    CPUView().environmentObject(SystemViewModel())
}

