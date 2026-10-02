//
//  RAMIndicatorsView.swift
//  Vitals
//
//  Created by Алексей on 8/22/26.
//

import SwiftUI

struct RAMIndicatorsView: View {
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("panelCompact") private var compact = true
    
    var body: some View {
        HStack {
            CircularIndicator(
                value: Double(vm.memoryPercent),
                text: String(format: "%.0f%%", vm.memoryPercent),
                label: "RAM"
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, compact ? 4 : 8)
    }
}
