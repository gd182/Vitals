import SwiftUI

struct ProcessRow: View {
    static let height: CGFloat = 20

    let process: ProcessUsage
    let value: String
    @State private var icon: NSImage?

    var body: some View {
        HStack {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "gearshape")
                }
            }
            .frame(width: 16, height: 16)
            Text(process.name).lineLimit(1).truncationMode(.tail).help(process.name)
            Spacer()
            Text(value).monospacedDigit().fixedSize()
        }
        .padding(.vertical, 2)
        .font(.caption)
        .frame(height: Self.height)
        .task(id: "\(process.id)-\(process.name)") {
            icon = NSRunningApplication(processIdentifier: process.id)?.icon
        }
    }
}
