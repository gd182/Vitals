import SwiftUI

struct HistoryChartView: View {
    let segments: [Segment]
    let namespace: String
    let unavailableMessage: String?
    @AppStorage private var height: Double
    @AppStorage("panelCompact") private var compact = true
    @State private var cursorIndex: Int?

    init(segments: [Segment], namespace: String, unavailableMessage: String? = nil) {
        self.segments = segments
        self.namespace = namespace
        self.unavailableMessage = unavailableMessage
        _height = AppStorage(wrappedValue: 60, "\(namespace).height")
    }

    var body: some View {
        let allPoints = segments.flatMap(\.points)
        let lastIndex = allPoints.last?.index ?? 0
        let firstIndex = allPoints.first?.index ?? 0
        GeometryReader { geometry in
            if let unavailableMessage {
                Text(LocalizedStringKey(unavailableMessage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("gpu-chart-unavailable")
            } else {
                ZStack(alignment: .topLeading) {
                    GradientLineView(segments: segments, namespace: namespace)
                        .allowsHitTesting(false)
                    Color.clear
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                let position = min(1, max(0, location.x / max(1, geometry.size.width)))
                                cursorIndex = firstIndex + Int((position * Double(lastIndex - firstIndex)).rounded())
                            case .ended:
                                cursorIndex = nil
                            }
                        }
                    if let index = cursorIndex,
                       let point = allPoints.first(where: { $0.index == index }) {
                        let x = lastIndex > firstIndex
                            ? CGFloat(index - firstIndex) / CGFloat(lastIndex - firstIndex) * geometry.size.width : 0
                        let y = (1 - min(100, max(0, CGFloat(point.value))) / 100) * geometry.size.height
                        Rectangle()
                            .fill(Color.primary.opacity(0.5))
                            .frame(width: 1, height: geometry.size.height)
                            .position(x: x, y: geometry.size.height / 2)
                            .allowsHitTesting(false)
                        Circle()
                            .fill(Color.primary)
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
        }
        .frame(height: compact ? max(24, height * 0.6) : height)
        .clipped()
    }
}
