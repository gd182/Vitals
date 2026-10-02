//
//  RamView.swift
//  Vitals
//
//  Created by Алексей on 7/6/26.
//

import SwiftUI

struct RAMView: View {
    var onSizeChange: ((CGSize) -> Void)? = nil
    @EnvironmentObject var vm: SystemViewModel
    
    @StateObject var config = DashboardConfig(namespace: "RAM")

    let blocks: [DashboardBlock] = [
        DashboardBlock(id: "ram_indicators", title: "block_indicators", content: .ramIndicators, hasSettings: false),
        DashboardBlock(id: "ram_details", title: "block_details_ram", content: .ramDetails, hasSettings: false),
        DashboardBlock(id: "ram_chart", title: "block_chart", content: .ramChart(namespace: "chart_RAM"), hasSettings: true),
        DashboardBlock(id: "ram_processes", title: "block_processes", content: .ramProcesses, hasSettings: false), 
    ]
    
    var body: some View {
        DashboardView(blocks: blocks, config: config, onSizeChange: onSizeChange)
        .onAppear {
            config.reconcile(ids: blocks.map(\.id))
        }
    }
}

#Preview {
    RAMView().environmentObject(SystemViewModel())
}
