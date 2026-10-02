import SwiftUI

struct Mini: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 8, weight: .light))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .frame(width: 36, height: 22)
    }
}
