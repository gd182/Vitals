//
//  ChartView.swift
//  Vitals
//
//  Created by Алексей on 8/22/26.
//

import SwiftUI

struct ChartView: View {
    let namespace: String
    let history: KeyPath<SystemViewModel, HistoryData>
    var status: KeyPath<SystemViewModel, ObjCGPUReadState>? = nil
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("panelCompact") private var compact = true
    
    var body: some View {
        VStack(alignment: .leading) {
            HistoryChartView(
                segments: vm[keyPath: history].segments(warning: vm.warningThreshold, critical: vm.criticalThreshold),
                namespace: namespace,
                unavailableMessage: status.flatMap {
                    let state = vm[keyPath: $0]
                    return state == .available ? nil : state.messageKey
                }
            )
        }
        .padding(compact ? 2 : 8)
    }
}
