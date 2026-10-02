import Foundation

nonisolated struct UsageColorScale {
    let warning: Float
    let critical: Float

    init(warning: Float = 50, critical: Float = 80) {
        self.warning = warning.isFinite ? min(100, max(0, warning)) : 50
        self.critical = max(self.warning, critical.isFinite ? min(100, max(0, critical)) : 80)
    }

    func category(for value: Float) -> TypeSegment {
        value < warning ? .normal : value < critical ? .warning : .critical
    }

    struct Stop {
        let category: TypeSegment
        let location: Double
    }

    func gradientStops(points: [HistoryPoint], width: Double, transitionWidth: Double) -> [Stop] {
        guard let first = points.first, let last = points.last else { return [] }
        let distance = Double(last.index - first.index)
        guard distance > 0 else { return [.init(category: category(for: first.value), location: 0)] }
        let thresholds = warning == critical ? [critical] : [warning, critical]
        var boundaries: [Stop] = []
        for (a, b) in zip(points, points.dropFirst()) {
            guard a.value != b.value, a.value.isFinite, b.value.isFinite else { continue }
            let increasing = b.value > a.value
            let crossed = thresholds.filter {
                increasing ? a.value < $0 && b.value >= $0 : a.value >= $0 && b.value < $0
            }
            let orderedCrossings = increasing ? crossed : Array(crossed.reversed())
            for threshold in orderedCrossings {
                let fraction = Double((threshold - a.value) / (b.value - a.value))
                // Match the cubic used to draw the line, rather than assuming a straight edge.
                var low = 0.0, high = 1.0
                for _ in 0..<20 {
                    let t = (low + high) / 2
                    if t * t * (3 - 2 * t) < fraction { low = t } else { high = t }
                }
                let t = (low + high) / 2
                let xFraction = 1.5 * t - 1.5 * t * t + t * t * t
                let index = Double(a.index) + Double(b.index - a.index) * xFraction
                boundaries.append(.init(category: category(for: increasing ? threshold : threshold.nextDown),
                    location: min(1, max(0, (index - Double(first.index)) / distance))))
            }
        }
        let halfWidth = transitionWidth.isFinite && width.isFinite && width > 0
            ? max(0, transitionWidth) / width / 2 : 0
        var current = category(for: first.value)
        var stops = [Stop(category: current, location: 0)]
        for (index, boundary) in boundaries.enumerated() {
            let previous = index > 0 ? boundaries[index - 1].location : 0
            let next = index + 1 < boundaries.count ? boundaries[index + 1].location : 1
            // Preserve a solid-color region even for a one-sample peak.
            let start = boundary.location - min(halfWidth, (boundary.location - previous) / 4)
            let end = boundary.location + min(halfWidth, (next - boundary.location) / 4)
            stops.append(.init(category: current, location: start))
            stops.append(.init(category: boundary.category, location: end))
            current = boundary.category
        }
        stops.append(.init(category: current, location: 1))
        return stops
    }
}
