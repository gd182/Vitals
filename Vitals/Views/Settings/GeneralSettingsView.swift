//
//  GeneralSettingsView.swift
//  Vitals
//
//  Created by Алексей on 7/30/26.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("updateInterval") var updateInterval: Double = 1.0
    
    let values: [Double] = [0.5, 1, 2, 3, 5, 10, 15, 30, 60]
    let labels = ["0.5 сек", "1 сек", "2 сек", "3 сек", "5 сек", "10 сек", "15 сек", "30 сек", "60 сек"]

    var body: some View {
        Text("General settings")
        HStack {
            Picker("", selection: $updateInterval) {
                ForEach(values.indices, id: \.self) { i in
                    Text(labels[i]).tag(values[i])
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 120)
            .controlSize(.large)
        }
    }
}
