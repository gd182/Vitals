

nonisolated enum ProcessListLayout {
    static let defaultVisibleRows = 10
    static let visibleRowRange = 3...10

    static func validatedVisibleRows(_ value: Int) -> Int {
        visibleRowRange.contains(value) ? value : defaultVisibleRows
    }
}
