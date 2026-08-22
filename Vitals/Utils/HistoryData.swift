//
//  HistoryData.swift
//  Vitals
//
//  Created by Алексей on 6/24/26.
//

import SwiftUI

enum TypeSegment {
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
    let id = UUID()
    var points: [(index: Int, value: Float)]
    let category: TypeSegment
}

struct HistoryData {
    
    private var buffer = CircularBuffer<Float>(initialCapacity: 60)
    
    mutating func append(_ value: Float) {
        buffer.append(value: value)
    }
    
    var segments: [Segment] {
        let warning = Float(UserDefaults.standard.double(forKey: "warningThreshold"))
        let critical = Float(UserDefaults.standard.double(forKey: "criticalThreshold"))
        let warnValue = warning > 0 ? warning : 50
        let critValue = critical > 0 ? critical : 80
        var prevPoint: (index: Int, value: Float)? = nil
        var idx = 0
        var segments: [Segment] = []
        let buffer = self.buffer.toArray()
        for value in buffer {
            let category = value < warnValue ? TypeSegment.normal : value < critValue ? TypeSegment.warning : TypeSegment.critical
            let newPoint = (index: idx, value: value)
            
            if segments.last?.category == category {
                segments[segments.count - 1].points.append(newPoint)
            } else {
                segments.append(Segment(
                    points: (prevPoint.map { [$0] } ?? []) + [newPoint],
                    category: category
                ))
            }
            idx += 1
            prevPoint = newPoint
        }
        return segments
    }
}
