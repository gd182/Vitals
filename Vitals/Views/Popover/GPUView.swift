//
//  RamView.swift
//  Vitals
//
//  Created by Алексей on 7/6/26.
//

import SwiftUI

struct GPUView: View {
    @EnvironmentObject var vm: SystemViewModel
        
    @StateObject var config = DashboardConfig(namespace: "GPU")
        
    let blocks: [DashboardBlock] = [
        DashboardBlock(id: "gpu_indicators", title: "block_indicators", content: .gpuIndicators, hasSettings: false),
        DashboardBlock(id: "gpu_details", title: "block_details_gpu", content: .gpuDetails, hasSettings: false),
        DashboardBlock(id: "gpu_chart_utl", title: "block_chart_gpu_util", content: .gpuChartUtl(namespace: "chart_GPU_utl"), hasSettings: true),
        DashboardBlock(id: "gpu_chart_render", title: "block_chart_gpu_render", content: .gpuChartRender(namespace: "chart_GPU_render"), hasSettings: true),
        DashboardBlock(id: "gpu_chart_tiler", title: "block_chart_gpu_tiler", content: .gpuChartTiler(namespace: "chart_GPU_tiler"), hasSettings: true),
        DashboardBlock(id: "gpu_chart_ane", title: "block_chart_gpu_ane", content: .gpuChartANE(namespace: "chart_GPU_ane"), hasSettings: true),
    ]
    
    var body: some View {
        DashboardView(blocks: blocks, config: config)
        .onAppear {
            let currentIDs = blocks.map { $0.id }
            config.order = config.order.filter { currentIDs.contains($0) }
            let newIDs = currentIDs.filter { !config.order.contains($0) }
            config.order.append(contentsOf: newIDs)
            
            vm.isMonitoringProcessesGPU = true
        }
        .onDisappear {vm.isMonitoringProcessesGPU = false}
    }
}

#Preview {
    GPUView().environmentObject(SystemViewModel())
}

