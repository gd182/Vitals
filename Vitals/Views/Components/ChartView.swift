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
    @EnvironmentObject var vm: SystemViewModel
    @AppStorage("panelCompact") private var compact = true
    
    var body: some View {
        VStack(alignment: .leading) {
            HistoryChartView(segments: vm[keyPath: history].segments(warning: vm.warningThreshold, critical: vm.criticalThreshold), namespace: namespace)
        }
        .padding(compact ? 2 : 8)
    }
}
