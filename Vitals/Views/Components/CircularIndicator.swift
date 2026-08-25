import SwiftUI

struct CircularIndicator: View {
    var value: Double
    var text: String
    var label: LocalizedStringKey

    
    var indicatorColor: Color {
        if value < 50 {
            Color.green
        }
        else if value < 80 {
            Color.yellow
        }
        else {
            Color.red
        }
    }
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(indicatorColor.opacity(0.2), lineWidth: 5)
                
                Circle()
                    .trim(from: 0, to: value / 100)
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
    CPUView()
}
