//
//  GPUDetailsView.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

import SwiftUI

struct GPUDetailsView: View {
    @EnvironmentObject var vm: SystemViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Занято: \(Format.formatBytes(vm.gpuVramUsed))")
            #if !arch(arm64)
            let free = vm.gpuVramTotal > vm.gpuVramUsed
                ? vm.gpuVramTotal - vm.gpuVramUsed
                : 0
            Text("Свободно: \(Format.formatBytes(free))")
            #endif
            Text("Всего: \(Format.formatBytes(vm.gpuVramTotal))")
        }
        .font(.caption)
        .padding(10)
    }
}
