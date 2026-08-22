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
                value: Double(vm.cpuTemperature),
                text: String(format: "%.0fC", vm.cpuTemperature),
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
    }
}
