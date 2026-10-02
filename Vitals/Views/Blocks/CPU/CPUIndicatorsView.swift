//
//  CPUIndicatorsView.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

import SwiftUI

struct CPUIndicatorsView: View {
    @EnvironmentObject var vm: SystemViewModel
    
    var body: some View {
        HStack {
            CircularIndicator(
                value: vm.cpuTemperature.map(Double.init),
                text: vm.cpuTemperature.map { String(format: "%.0fC", $0) } ?? "N/A",
                label: "temp"
            )
            .padding()
            CircularIndicator(
                value: Double(vm.cpuUsage),
                text: String(format: "%.0f%%", vm.cpuUsage),
                label: "CPU"
            )
            .padding()
        }
        .padding(10)
        .onAppear { vm.isMonitoringTemperature = true }
        .onDisappear { vm.isMonitoringTemperature = false }
    }
}
