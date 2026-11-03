//
//  GPUIndicatorsView.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

import SwiftUI

struct GPUIndicatorsView: View {
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("panelCompact") private var compact = true
    
    var body: some View {
        HStack {
            CircularIndicator(
                value: vm.gpuRenderUtilizationState == .available ? Double(vm.gpuRenderUtilization) : nil,
                text: vm.gpuRenderUtilizationState == .available ? String(format: "%.0f%%", vm.gpuRenderUtilization) : "N/A",
                label: "gpu_label_render"
            )
            .help(LocalizedStringKey(vm.gpuRenderUtilizationState.messageKey))
            .frame(maxWidth: .infinity)
            CircularIndicator(
                value: vm.gpuUtilizationState == .available ? Double(vm.gpuUtilization) : nil,
                text: vm.gpuUtilizationState == .available ? String(format: "%.0f%%", vm.gpuUtilization) : "N/A",
                label: "gpu_label_util"
            )
            .help(LocalizedStringKey(vm.gpuUtilizationState.messageKey))
            .frame(maxWidth: .infinity)
            CircularIndicator(
                value: vm.gpuTilerUtilizationState == .available ? Double(vm.gpuTilerUtilization) : nil,
                text: vm.gpuTilerUtilizationState == .available ? String(format: "%.0f%%", vm.gpuTilerUtilization) : "N/A",
                label: "gpu_label_tiler"
            )
            .help(LocalizedStringKey(vm.gpuTilerUtilizationState.messageKey))
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, compact ? 4 : 8)
    }
}
