import Foundation

nonisolated struct MonitoringPreferences: Equatable {
    static let intervals: [Double] = [0.5, 1, 2, 3, 5, 10, 15, 30, 60]
    var foregroundInterval: TimeInterval
    var backgroundInterval: TimeInterval
    var processInterval: TimeInterval
    var temperatureInterval: TimeInterval
    var warningThreshold: Float
    var criticalThreshold: Float

    init(defaults: UserDefaults = .standard) {
        func interval(_ key: String, fallback: Double) -> Double {
            guard let number = defaults.object(forKey: key) as? NSNumber,
                  number.doubleValue.isFinite, number.doubleValue > 0 else { return fallback }
            return min(60, max(0.5, number.doubleValue))
        }
        foregroundInterval = interval("updateInterval", fallback: 1)
        // Keep the existing user's cadence until they select a separate background interval.
        backgroundInterval = interval("backgroundUpdateInterval", fallback:
            defaults.object(forKey: "updateInterval") == nil ? 3 : foregroundInterval)
        processInterval = interval("processUpdateInterval", fallback: 2)
        temperatureInterval = interval("temperatureUpdateInterval", fallback: 3)
        func threshold(_ key: String, fallback: Float) -> Float {
            guard let number = defaults.object(forKey: key) as? NSNumber,
                  number.floatValue.isFinite else { return fallback }
            return min(100, max(0, number.floatValue))
        }
        warningThreshold = threshold("warningThreshold", fallback: 50)
        criticalThreshold = max(warningThreshold, threshold("criticalThreshold", fallback: 80))
    }
}
