//
//  RAMIndicatorsView.swift
//  Vitals
//
//  Created by Алексей on 8/22/26.
//

import SwiftUI


struct RAMIndicatorsView: View {
    @AppStorage("ramIndicatorStyle")
        private var ramIndicatorStyle: RAMIndicatorStyle = .ring
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("panelCompact") private var compact = true
    
    var body: some View {
        HStack {
            switch ramIndicatorStyle {
                case .ring:
                    CircularIndicator(
                        value: Double(vm.memoryPercent),
                        text: String(format: "%.0f%%", vm.memoryPercent),
                        label: "RAM"
                    )
                    .frame(maxWidth: .infinity)
                case .value:
                    VStack(spacing: 4) {
                        Text(Format.formatBytes(vm.memoryUsedBytes))
                            .font(.title2.bold())
                        HStack(spacing: 4) {
                            Text("memory_total")
                            Text(Format.formatBytes(vm.memoryTotalBytes))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, compact ? 4 : 8)
    }
}
