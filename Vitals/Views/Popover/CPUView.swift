import SwiftUI

struct CPUView: View {
    var onSizeChange: ((CGSize) -> Void)? = nil
    @EnvironmentObject var vm: SystemViewModel
    
    @StateObject var config = DashboardConfig(namespace: "CPU")
    
    let blocks: [DashboardBlock] = [
        DashboardBlock(id: "cpu_indicators", title: "block_indicators", content: .cpuIndicators, hasSettings: false),
        DashboardBlock(id: "cpu_details", title: "block_details_cpu", content: .cpuDetails, hasSettings: false),
        DashboardBlock(id: "cpu_chart", title: "block_chart", content: .cpuChart(namespace: "chart_CPU"), hasSettings: true),
        DashboardBlock(id: "cpu_processes", title: "block_processes", content: .cpuProcesses, hasSettings: false),
    ]
    
    var body: some View {
        DashboardView(blocks: blocks, config: config, onSizeChange: onSizeChange)
        .onAppear {
            config.reconcile(ids: blocks.map(\.id))
        }
    }
}

#Preview {
    CPUView().environmentObject(SystemViewModel())
}
