//
//  RamView.swift
//  Vitals
//
//  Created by Алексей on 7/6/26.
//

import SwiftUI

struct RAMView: View {
    @EnvironmentObject var vm: SystemViewModel
    
    @StateObject var config = DashboardConfig(namespace: "RAM")

    let blocks: [DashboardBlock] = [
        DashboardBlock(id: "ram_indicators", title: "Индикаторы", content: .ramIndicators, hasSettings: false),
        DashboardBlock(id: "ram_details", title: "Детали RAM", content: .ramDetails, hasSettings: false),
        DashboardBlock(id: "ram_chart", title: "График", content: .ramChart(namespace: "chart_RAM"), hasSettings: true),
        DashboardBlock(id: "ram_processes", title: "Процессы", content: .ramProcesses, hasSettings: false), 
    ]
    
    var body: some View {
        DashboardView(blocks: blocks, config: config)
        .onAppear {
            let currentIDs = blocks.map { $0.id }
            config.order = config.order.filter { currentIDs.contains($0) }
            let newIDs = currentIDs.filter { !config.order.contains($0) }
            config.order.append(contentsOf: newIDs)
            
            vm.isMonitoringProcessesRAM = true
        }
        .onDisappear {vm.isMonitoringProcessesRAM = false}
    }
}

#Preview {
    RAMView().environmentObject(SystemViewModel())
}

