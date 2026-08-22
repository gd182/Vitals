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
    
    var body: some View {
        VStack(alignment: .leading) {
            HistoryChartView(segments: vm[keyPath: history].segments, namespace: namespace)
        }
        .padding(8)
    }
}
