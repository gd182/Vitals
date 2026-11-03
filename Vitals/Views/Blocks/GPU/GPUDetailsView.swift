//
//  GPUDetailsView.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

import SwiftUI

struct GPUDetailsView: View {
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("panelCompact") private var compact = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack {
                Text("memory_used")
                Spacer()
                Text(vm.gpuVramUsedState == .available ? Format.formatBytes(vm.gpuVramUsed) : "N/A")
                    .help(LocalizedStringKey(vm.gpuVramUsedState.messageKey))
            }
            #if !arch(arm64)
            let free = vm.gpuVramTotal > vm.gpuVramUsed
                ? vm.gpuVramTotal - vm.gpuVramUsed
                : 0
            HStack {
                Text("memory_free")
                Spacer()
                Text(vm.gpuVramUsedState == .available && vm.gpuVramTotalState == .available
                     ? Format.formatBytes(free) : "N/A")
            }
            #endif
            HStack {
                MetricHelpLabel(title: "memory_total", topic: .gpuMemory)
                Spacer()
                Text(vm.gpuVramTotalState == .available ? Format.formatBytes(vm.gpuVramTotal) : "N/A")
                    .help(LocalizedStringKey(vm.gpuVramTotalState.messageKey))
            }
        }
        .font(.caption)
        .monospacedDigit()
    }
}
