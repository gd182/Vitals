//
//  HistoryData.swift
//  Vitals
//
//  Created by Алексей on 6/24/26.
//

import SwiftUI

nonisolated enum TypeSegment: Equatable {
    case normal
    case warning
    case critical
    
    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}

struct Segment: Identifiable {
    var id: String { "\(category)-\(points.first?.index ?? 0)" }
    var points: [HistoryPoint]
    let category: TypeSegment
}

nonisolated struct HistoryPoint {
    let index: Int
    let value: Float
    let timestamp: Date
}

struct HistoryData {
    
    private var buffer = CircularBuffer<(value: Float?, timestamp: Date)>(initialCapacity: 60)
    
    mutating func append(_ value: Float?, timestamp: Date = Date()) {
        buffer.append(value: (value.flatMap { $0.isFinite ? $0 : nil }, timestamp))
    }
    
    func segments(warning: Float, critical: Float) -> [Segment] {
        let colorScale = UsageColorScale(warning: warning, critical: critical)
        var prevPoint: HistoryPoint? = nil
        var segments: [Segment] = []
        for index in 0..<buffer.count {
            guard let sample = buffer.get(index: index) else { continue }
            guard let value = sample.value else {
                prevPoint = nil
                continue
            }
            let category = colorScale.category(for: value)
            let newPoint = HistoryPoint(index: index, value: value, timestamp: sample.timestamp)
            
            if prevPoint != nil && segments.last?.category == category {
                segments[segments.count - 1].points.append(newPoint)
            } else {
                segments.append(Segment(
                    points: (prevPoint.map { [$0] } ?? []) + [newPoint],
                    category: category
                ))
            }
            prevPoint = newPoint
        }
        return segments
    }

    static func continuousRuns(in segments: [Segment]) -> [[HistoryPoint]] {
        var runs: [[HistoryPoint]] = []
        for point in segments.flatMap(\.points) {
            if runs.last?.last?.index == point.index { continue }
            if let last = runs.last?.last, point.index == last.index + 1 {
                runs[runs.count - 1].append(point)
            } else {
                runs.append([point])
            }
        }
        return runs
    }
}
