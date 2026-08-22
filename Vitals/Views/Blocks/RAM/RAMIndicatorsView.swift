//
//  RAMIndicatorsView.swift
//  Vitals
//
//  Created by Алексей on 8/22/26.
//

import SwiftUI

struct RAMIndicatorsView: View {
    @EnvironmentObject var vm: SystemViewModel
    
    var body: some View {
        HStack {
            CircularIndicator(
                value: Double(vm.memoryPercent),
                text: String(format: "%.0f%%", vm.memoryPercent),
                label: "RAM"
            )
            .padding()
        }
        .padding(10)
    }
}
