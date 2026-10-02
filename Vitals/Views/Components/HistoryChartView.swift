import SwiftUI

struct HistoryChartView: View {
    let segments: [Segment]
    let namespace: String
    @AppStorage private var height: Double
    @State private var cursorIndex: Int?

    init(segments: [Segment], namespace: String) {
        self.segments = segments
        self.namespace = namespace
        _height = AppStorage(wrappedValue: 60, "\(namespace).height")
    }

    var body: some View {
        let allPoints = segments.flatMap(\.points)
        let lastIndex = allPoints.last?.index ?? 0
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                GradientLineView(segments: segments, namespace: namespace)
                    .allowsHitTesting(false)
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let position = min(1, max(0, location.x / max(1, geometry.size.width)))
                            cursorIndex = Int((position * Double(lastIndex)).rounded())
                        case .ended:
                            cursorIndex = nil
                        }
                    }
                if let index = cursorIndex,
                   let point = allPoints.first(where: { $0.index == index }) {
                    let x = lastIndex > 0 ? CGFloat(index) / CGFloat(lastIndex) * geometry.size.width : 0
                    let y = (1 - min(100, max(0, CGFloat(point.value))) / 100) * geometry.size.height
                    Rectangle()
                        .fill(.white.opacity(0.6))
                        .frame(width: 1, height: geometry.size.height)
                        .position(x: x, y: geometry.size.height / 2)
                        .allowsHitTesting(false)
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                        .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f%%", point.value)).font(.caption.bold())
                        Text(point.timestamp.formatted(date: .omitted, time: .standard)).font(.caption2)
                    }
                    .padding(4)
                    .frame(width: 88, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .position(x: min(max(44, x + 48), max(44, geometry.size.width - 44)), y: 22)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(height: height)
        .clipped()
    }
}
