//
//  RAMDetailsView.swift
//  Vitals
//
//  Created by Алексей on 8/22/26.
//

import SwiftUI

struct RAMDetailsView: View {
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("panelCompact") private var compact = true
    @AppStorage("ramShowSwap") private var showSwap = true
    @AppStorage("ramShowMemoryPressure") private var showMemoryPressure = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack {
                Text("memory_used")
                Spacer()
                Text(Format.formatBytes(vm.memoryUsedBytes))
            }
            HStack {
                Text("memory_free")
                Spacer()
                Text(Format.formatBytes(vm.memoryTotalBytes - vm.memoryUsedBytes))
            }
            HStack {
                Text("memory_total")
                Spacer()
                Text(Format.formatBytes(vm.memoryTotalBytes))
            }
            if showSwap {
                HStack {
                    MetricHelpLabel(title: "memory_swap_used", topic: .memorySwap)
                    Spacer()

                    if let swapUsedBytes = vm.swapUsedBytes {
                        Text(Format.formatBytes(swapUsedBytes))
                    } else {
                        Text("N/A")
                    }
                }
            }
            if showMemoryPressure {
                HStack {
                    MetricHelpLabel(title: "memory_pressure", topic: .memoryPressure)
                    Spacer()

                    switch vm.memoryPressure {
                        case .normal:
                            Text("memory_pressure_normal")
                                .foregroundStyle(.green)
                        case .warning:
                            Text("memory_pressure_warning")
                                .foregroundStyle(.yellow)
                        case .critical:
                            Text("memory_pressure_critical")
                                .foregroundStyle(.red)
                        case .unknown:
                            Text("N/A")
                                .foregroundStyle(.secondary)
                        @unknown default:
                            Text("N/A")
                                .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .font(.caption)
        .monospacedDigit()
    }
}
