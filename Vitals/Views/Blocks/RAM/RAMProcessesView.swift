//
//  RAMProcessesView.swift
//  Vitals
//
//  Created by Алексей on 8/22/26.
//

import SwiftUI

struct RAMProcessesView: View {
    @EnvironmentObject var vm: SystemViewModel
    
    var body: some View {
        VStack {
            Text("Процессы")
            ForEach(vm.topProcessesByRAM.indices, id: \.self) { i in
                let p = vm.topProcessesByRAM[i]
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
                    Text(Format.formatBytes(UInt64(p["value"] as? Double ?? 0)))
                }
                .padding(.vertical, 2)
                .font(.caption)
            }
            .padding(1)
        }
        .padding(10)
    }
}
