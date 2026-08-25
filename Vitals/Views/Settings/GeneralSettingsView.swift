//
//  GeneralSettingsView.swift
//  Vitals
//
//  Created by Алексей on 7/30/26.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("updateInterval") var updateInterval: Double = 1.0
    
    @EnvironmentObject var langManager: LanguageManager
    
    let values: [Double] = [0.5, 1, 2, 3, 5, 10, 15, 30, 60]
    
    let valuesLang: [String] = ["en", "ru", "de"]
    let labelsLang = ["English", "Русский", "Deutsch"]

    var body: some View {
        VStack {
            Text("settings_tab_general")
            HStack {
                Picker(selection: $updateInterval) {
                    ForEach(values, id: \.self) { val in
                        (Text(verbatim: val < 1 ? "0.5" : "\(Int(val))") + Text(verbatim: " ") + Text("unit_sec"))
                            .tag(val)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 120)
                .controlSize(.large)
                Picker(selection: $langManager.appLanguage) {
                    ForEach(valuesLang.indices, id: \.self) { i in
                        Text(labelsLang[i]).tag(valuesLang[i])
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 120)
                .controlSize(.large)
            }
        }
    }
}
