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
            HStack {
                Text("memory_used")
                Spacer()
                Text(Format.formatBytes(vm.gpuVramUsed))
            }
            #if !arch(arm64)
            let free = vm.gpuVramTotal > vm.gpuVramUsed
                ? vm.gpuVramTotal - vm.gpuVramUsed
                : 0
            HStack {
                Text("memory_free")
                Spacer()
                Text(Format.formatBytes(free))
            }
            #endif
            HStack {
                Text("memory_total")
                Spacer()
                Text(Format.formatBytes(vm.gpuVramTotal))
            }
        }
        .font(.caption)
        .padding(10)
    }
}
