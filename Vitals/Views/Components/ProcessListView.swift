import SwiftUI

struct ProcessListView: View {
    let state: ProcessListState
    let processes: [ProcessUsage]
    var visibleRows: Int = ProcessListLayout.defaultVisibleRows
    let formattedValue: (ProcessUsage) -> String

    private let rowSpacing: CGFloat = 4
    private var listHeight: CGFloat {
        let rows = min(processes.count, ProcessListLayout.validatedVisibleRows(visibleRows))
        guard rows > 0 else { return 0 }
        return CGFloat(rows) * ProcessRow.height + CGFloat(rows - 1) * rowSpacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            switch state {
            case .inactive:
                EmptyView()
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            case .ready:
                if processes.isEmpty {
                    Text("panel_no_processes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: rowSpacing) {
                            ForEach(processes) { process in
                                ProcessRow(process: process, value: formattedValue(process))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: listHeight)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monospacedDigit()
    }
}
