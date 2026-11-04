import Foundation
import Testing

@MainActor
struct UpdateIntervalPreferencesTests {
    @Test
    func supportedIntervalsUseStableSecondValues() {
        #expect(UpdateCheckInterval.allCases == [.sixHours, .twelveHours, .daily, .weekly])
        #expect(UpdateCheckInterval.allCases.map(\.rawValue) == [21600, 43200, 86400, 604800])
        for interval in UpdateCheckInterval.allCases {
            #expect(interval.id == interval)
            #expect(interval.timeInterval == TimeInterval(interval.rawValue))
        }
    }

    @Test
    func existingInstallationsKeepDailyChecks() throws {
        let suite = "VitalsTests.UpdateInterval.Defaults.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        #expect(preferences.checkInterval == .daily)
        #expect(!preferences.automaticChecksEnabled)
        let attempt = Date(timeIntervalSince1970: 1_700_000_000)
        preferences.recordAttempt(at: attempt)
        preferences.automaticChecksEnabled = true
        #expect(preferences.checkInterval == .daily)
        #expect(preferences.lastAttempt == attempt)
    }

    @Test
    func intervalPersistsWithoutChangingOtherPreferences() throws {
        let suite = "VitalsTests.UpdateInterval.Persistence.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        let attempt = Date(timeIntervalSince1970: 1_700_000_000)
        let success = attempt.addingTimeInterval(10)
        preferences.recordAttempt(at: attempt)
        preferences.recordSuccessfulCheck(at: success)
        for interval in UpdateCheckInterval.allCases {
            preferences.checkInterval = interval
            #expect(defaults.object(forKey: "automaticUpdateCheckInterval") as? Int == interval.rawValue)
            let reloaded = UpdatePreferences(defaults: try #require(UserDefaults(suiteName: suite)))
            #expect(reloaded.checkInterval == interval)
            #expect(!reloaded.automaticChecksEnabled)
            #expect(reloaded.lastAttempt == attempt)
            #expect(reloaded.lastSuccessfulCheck == success)
        }
    }

    @Test
    func invalidSavedIntervalsFallBackToDaily() throws {
        let suite = "VitalsTests.UpdateInterval.Invalid.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        for value: Any in [0, -1, 12345, "86400", true, 21600.5, ["seconds": 86400]] {
            defaults.set(value, forKey: "automaticUpdateCheckInterval")
            #expect(preferences.checkInterval == .daily)
        }
        preferences.checkInterval = .sixHours
        #expect(preferences.checkInterval == .sixHours)
    }
}
