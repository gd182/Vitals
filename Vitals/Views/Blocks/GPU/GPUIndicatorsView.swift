//
//  GPUIndicatorsView.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

import SwiftUI

struct GPUIndicatorsView: View {
    @EnvironmentObject var vm: SystemViewModel
    
    var body: some View {
        HStack {
            CircularIndicator(
                value: Double(vm.gpuRenderUtilization),
                text: String(format: "%.0f%%", vm.gpuRenderUtilization),
                label: "gpu_label_render"
            )
            .padding()
            CircularIndicator(
                value: Double(vm.gpuUtilization),
                text: String(format: "%.0f%%", vm.gpuUtilization),
                label: "gpu_label_util"
            )
            .padding()
            CircularIndicator(
                value: Double(vm.gpuTilerUtilization),
                text: String(format: "%.0f%%", vm.gpuTilerUtilization),
                label: "gpu_label_tiler"
            )
            .padding()
        }
        .padding(10)
    }
}
