//
//  ThresholdsSettingsView.swift
//  Vitals
//
//  Created by Алексей on 7/30/26.
//

import SwiftUI

struct ThresholdsSettingsView: View {
    
    @AppStorage("warningThreshold") var warningThreshold: Double = 50
    @AppStorage("criticalThreshold") var criticalThreshold: Double = 80
    
    var body: some View {
        VStack {
            Text("settings_tab_thresholds")
            HStack {
                Text("threshold_warning").frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: $warningThreshold, in: 0...100, step: 1)
                    .onChange(of: warningThreshold) { newValue in
                        if newValue > criticalThreshold {
                            criticalThreshold = newValue
                        }
                    }
                    .frame(maxWidth: 200)
                Text(String(format: "%.0f%%", warningThreshold)).frame(width: 40)
            }
            HStack {
                Text("threshold_critical").frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: $criticalThreshold, in: 0...100, step: 1)
                    .onChange(of: criticalThreshold) { newValue in
                        if newValue < warningThreshold {
                            warningThreshold = newValue
                        }
                    }
                    .frame(maxWidth: 200)
                Text(String(format: "%.0f%%", criticalThreshold)).frame(width: 40)
            }
        }
        .padding(16)
    }
}
