//
//  CPUDetailsView.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

import SwiftUI

struct CPUDetailsView: View {
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("panelCompact") private var compact = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack {
                Text("cpu_system")
                Spacer()
                Text(String(format: "%.1f%%", vm.cpuSystem))
            }
            HStack {
                Text("cpu_user")
                Spacer()
                Text(String(format: "%.1f%%", vm.cpuUser))
            }
            HStack {
                Text("cpu_idle")
                Spacer()
                Text(String(format: "%.1f%%", vm.cpuIdle))
            }
        }
        .font(.caption)
        .monospacedDigit()
    }
}
