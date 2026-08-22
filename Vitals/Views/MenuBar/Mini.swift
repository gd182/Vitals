import SwiftUI

struct Mini: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack() {
            Text(title)
                .font(.system(size: 8, weight: .light))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .scaleEffect(CGSize(width: 1.0, height: 0.8))
    }
}
