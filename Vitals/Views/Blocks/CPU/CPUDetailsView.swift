//
//  CPUDetailsView.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

import SwiftUI

struct CPUDetailsView: View {
    @EnvironmentObject var vm: SystemViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Система: \(String(format: "%.1f", vm.cpuSystem))%")
            Text("Пользователь: \(String(format: "%.1f", vm.cpuUser))%")
            Text("Простой: \(String(format: "%.1f", vm.cpuIdle))%")
        }
        .font(.caption)
        .padding(10)
    }
}
