import SwiftUI

struct CircularIndicator: View {
    var value: Double?
    var text: String
    var label: LocalizedStringKey
    @AppStorage("panelCompact") private var compact = true
    private var palette = UsagePalette()
    @AppStorage("warningThreshold") private var warningThreshold: Double = 50
    @AppStorage("criticalThreshold") private var criticalThreshold: Double = 80

    
    var indicatorColor: Color {
        guard let value, value.isFinite else { return .secondary }
        return palette.color(for: UsageColorScale(warning: Float(warningThreshold), critical: Float(criticalThreshold))
            .category(for: Float(value)))
    }

    private var fraction: Double {
        guard let value, value.isFinite else { return 0 }
        return min(1, max(0, value / 100))
    }
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(indicatorColor.opacity(0.2), lineWidth: 5)
                
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(indicatorColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(text)
                    .font(.system(size: compact ? 11 : 14, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: compact ? 40 : 58, height: compact ? 40 : 58)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    CircularIndicator(value: 65, text: "65%", label: "CPU")
}
