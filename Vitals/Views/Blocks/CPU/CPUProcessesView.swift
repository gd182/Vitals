//
//  CPUProcessesView.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

import SwiftUI

struct CPUProcessesView: View {
    @EnvironmentObject var vm: SystemViewModel
    
    var body: some View {
        VStack {
            ForEach(vm.topProcessesByCPU.indices, id: \.self) { i in
                let p = vm.topProcessesByCPU[i]
                HStack {
                    if let app = NSWorkspace.shared.runningApplications.first(where: {
                        $0.processIdentifier == p["pid"] as? Int32
                    }),
                       let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "gearshape")
                            .frame(width: 16, height: 16)
                    }
                    Text(p["name"] as? String ?? "").lineLimit(1).truncationMode(.tail)
                    Spacer()
                    Text(String(format: "%.1f%%", p["value"] as? Double ?? 0))
                }
                .padding(.vertical, 2)
                .font(.caption)
            }
            .frame(height: 12)
        }
        .padding(10)
    }
}
