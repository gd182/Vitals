//
//  ChartSettingsView.swift
//  Vitals
//
//  Created by Алексей on 8/19/26.
//

import SwiftUI

struct ChartSettingsView: View {
    let namespace: String

    @AppStorage var lineWidth: Double
    @AppStorage var height: Double
    @AppStorage var transitionWidth: Double
    
    init(namespace: String) {
            self.namespace = namespace
            _lineWidth = AppStorage(wrappedValue: 1.5, "\(namespace).lineWidth")
            _height = AppStorage(wrappedValue: 60.0, "\(namespace).height")
            _transitionWidth = AppStorage(wrappedValue: 20.0, "\(namespace).transitionWidth")
        }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Толщина линии").frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: $lineWidth, in: 0.5...4, step: 0.5)
                    .frame(width: 120)
                Text(String(format: "%.1f", lineWidth)).frame(width: 30)
            }
            HStack {
                Text("Высота").frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: $height, in: 30...120, step: 10)
                    .frame(width: 120)
                Text("\(Int(height))").frame(width: 30)
            }
            HStack {
                Text("Переход").frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: $transitionWidth, in: 0...50, step: 5)
                    .frame(width: 120)
                Text("\(Int(transitionWidth))").frame(width: 30)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

