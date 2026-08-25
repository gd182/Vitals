//
//  RAMDetailsView.swift
//  Vitals
//
//  Created by Алексей on 8/22/26.
//

import SwiftUI

struct RAMDetailsView: View {
    @EnvironmentObject var vm: SystemViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
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
        }
        .font(.caption)
        .padding(10)
    }
}
