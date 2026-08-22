//
//  HistoryChartView.swift
//  Vitals
//
//  Created by Алексей on 6/30/26.
//

import SwiftUI
import Charts

struct HistoryChartView: View {
    let segments: [Segment]
    
    let namespace: String
    
    @State private var cursorX: CGFloat? = nil
    @State private var cursorIndex: Int? = nil
    
    var body: some View {
        Chart {
            ForEach(segments.indices, id: \.self) { segIdx in
                let segment = segments[segIdx]
                let color: Color = segment.category == .normal ? .green :
                                   segment.category == .warning ? .yellow : .red
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .clipped()
        .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    withAnimation(.none) {
                                        cursorX = location.x
                                        cursorIndex = proxy.value(atX: location.x, as: Int.self)
                                    }
                                case .ended:
                                    cursorX = nil
                                    cursorIndex = nil
                                }
                            }
                        if let x = cursorX, let idx = cursorIndex,
                           let value = segments.flatMap({ $0.points }).first(where: { $0.index == idx })?.value,
                           let y = proxy.position(forY: Double(value)) {
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                                .position(x: x, y: y)
                                .allowsHitTesting(false)
                        }
                        if let x = cursorX {
                            Rectangle()
                                .fill(.white.opacity(0.6))
                                .frame(width: 1)
                                .position(x: x, y: geo.size.height / 2)
                                .allowsHitTesting(false)
                        }
                        if let x = cursorX, let idx = cursorIndex {
                            let totalPoints = segments.flatMap { $0.points }.count
                            let secondsAgo = totalPoints - 1 - idx
                            let time = Date().addingTimeInterval(-Double(secondsAgo))
                            
                            let value = segments.flatMap { $0.points }.first { $0.index == idx }?.value
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%.0f%%", value ?? 0))
                                    .font(.caption.bold())
                                Text(time.formatted(date: .omitted, time: .standard))
                                    .font(.caption2)
                            }
                            .padding(4)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            .position(x: x + 40, y: 20)
                            .allowsHitTesting(false)
                        }
                    }
                }
        .frame(height: 60)
        .overlay(GradientLineView(segments: segments, namespace: namespace))

    }
}
