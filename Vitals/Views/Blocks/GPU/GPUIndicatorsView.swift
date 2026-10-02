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
                value: Double(vm.gpuRenderUtilization),
                text: String(format: "%.0f%%", vm.gpuRenderUtilization),
                label: "gpu_label_render"
            )
            .frame(maxWidth: .infinity)
            CircularIndicator(
                value: Double(vm.gpuUtilization),
                text: String(format: "%.0f%%", vm.gpuUtilization),
                label: "gpu_label_util"
            )
            .frame(maxWidth: .infinity)
            CircularIndicator(
                value: Double(vm.gpuTilerUtilization),
                text: String(format: "%.0f%%", vm.gpuTilerUtilization),
                label: "gpu_label_tiler"
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, compact ? 4 : 8)
    }
}
