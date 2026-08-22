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
            Text("Занято: \(Format.formatBytes(vm.memoryUsedBytes))")
            Text("Свободно: \(Format.formatBytes(vm.memoryTotalBytes - vm.memoryUsedBytes))")
            Text("Всего: \(Format.formatBytes(vm.memoryTotalBytes))")
        }
        .font(.caption)
        .padding(10)
    }
}
