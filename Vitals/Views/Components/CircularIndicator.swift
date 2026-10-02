import SwiftUI

struct CircularIndicator: View {
    var value: Double?
    var text: String
    var label: LocalizedStringKey
    @AppStorage("warningThreshold") private var warningThreshold: Double = 50
    @AppStorage("criticalThreshold") private var criticalThreshold: Double = 80

    
    var indicatorColor: Color {
        guard let value, value.isFinite else { return .secondary }
        return UsageColorScale(warning: Float(warningThreshold), critical: Float(criticalThreshold))
            .category(for: Float(value)).color
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
                    .font(.headline)
            }
            .frame(width: 40, height: 40)
            Text(label)
                .font(.caption)
        }
    }
}

#Preview {
    CircularIndicator(value: 65, text: "65%", label: "CPU")
}
