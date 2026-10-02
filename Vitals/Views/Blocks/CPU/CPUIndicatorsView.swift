//
//  CPUIndicatorsView.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

import SwiftUI

struct CPUIndicatorsView: View {
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("panelCompact") private var compact = true
    
    var body: some View {
        HStack {
            CircularIndicator(
                value: vm.cpuTemperature.map(Double.init),
                text: vm.cpuTemperature.map { String(format: "%.0fC", $0) } ?? "N/A",
                label: "cpu_temperature"
            )
            .frame(maxWidth: .infinity)
            CircularIndicator(
                value: Double(vm.cpuUsage),
                text: String(format: "%.0f%%", vm.cpuUsage),
                label: "CPU"
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, compact ? 4 : 8)
        .onAppear { vm.isMonitoringTemperature = true }
        .onDisappear { vm.isMonitoringTemperature = false }
    }
}
