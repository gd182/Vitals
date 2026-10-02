import SwiftUI

struct ChartSettingsView: View {
    let namespace: String

    var body: some View {
        ChartControlsView(namespace: namespace)
            .padding(20)
            .frame(width: 320)
    }
}

struct ChartControlsView: View {
    let namespace: String
    @AppStorage private var lineWidth: Double
    @AppStorage private var height: Double
    @AppStorage private var transitionWidth: Double

    init(namespace: String) {
        self.namespace = namespace
        _lineWidth = AppStorage(wrappedValue: 1.5, "\(namespace).lineWidth")
        _height = AppStorage(wrappedValue: 60, "\(namespace).height")
        _transitionWidth = AppStorage(wrappedValue: 20, "\(namespace).transitionWidth")
    }

    private static let preview = Segment(points: [Float(12), 25, 18, 58, 72, 48, 92, 84, 44, 28, 36, 20]
        .enumerated().map { HistoryPoint(index: $0.offset, value: $0.element, timestamp: Date(timeIntervalSince1970: 0)) },
        category: .normal)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GradientLineView(segments: [Self.preview], namespace: namespace)
                .frame(height: min(120, max(30, height)))
                .accessibilityHidden(true)
            control("chart_line_width", value: $lineWidth, range: 0.5...4, step: 0.5, decimals: true)
            control("chart_height", value: $height, range: 30...120, step: 10)
            control("chart_transition", value: $transitionWidth, range: 0...50, step: 5)
            HStack {
                Spacer()
                Button {
                    for key in ["lineWidth", "height", "transitionWidth"] {
                        UserDefaults.standard.removeObject(forKey: "\(namespace).\(key)")
                    }
                } label: { Image(systemName: "arrow.counterclockwise") }
                .help("panel_reset")
            }
        }
    }

    private func control(_ title: LocalizedStringKey, value: Binding<Double>,
                         range: ClosedRange<Double>, step: Double, decimals: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack {
                Slider(value: value, in: range, step: step).accessibilityLabel(Text(title))
                Text(decimals ? String(format: "%.1f", value.wrappedValue) : "\(Int(value.wrappedValue))")
                    .monospacedDigit().frame(width: 36, alignment: .trailing)
            }
        }
    }
}
