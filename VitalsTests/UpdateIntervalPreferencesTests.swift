import Foundation
import Testing
import SwiftUI

@MainActor
private struct UpdateIntervalStorageProbe {
    @AppStorage private var storedInterval: UpdateCheckInterval

    init(defaults: UserDefaults) {
        _storedInterval = AppStorage(wrappedValue: .daily, "automaticUpdateCheckInterval", store: defaults)
    }

    var interval: UpdateCheckInterval {
        get { storedInterval }
        nonmutating set { storedInterval = newValue }
    }
}

@MainActor
struct UpdateIntervalPreferencesTests {
    @Test
    func allIntervalLabelsHaveTranslations() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        let titles = UpdateCheckInterval.allCases.map(\.titleKey)
        #expect(Set(titles).count == UpdateCheckInterval.allCases.count)
        for key in ["updates_check_interval"] + titles {
            let entry = try #require(strings[key] as? [String: Any])
            let translations = try #require(entry["localizations"] as? [String: Any])
            for language in ["en", "ru", "de"] {
                let translation = try #require(translations[language] as? [String: Any])
                let unit = try #require(translation["stringUnit"] as? [String: Any])
                let value = try #require(unit["value"] as? String)
                #expect(unit["state"] as? String == "translated")
                #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if language == "ru" {
                    #expect(!value.unicodeScalars.contains {
                        (65...90).contains($0.value) || (97...122).contains($0.value) || $0.value < 32
                    })
                }
            }
        }
    }

    @Test
    func appStorageAgreesAfterNormalizingSavedValues() throws {
        let suite = "VitalsTests.UpdateInterval.AppStorage.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        #expect(UpdateIntervalStorageProbe(defaults: defaults).interval == .daily)
        for interval in UpdateCheckInterval.allCases {
            let storage = UpdateIntervalStorageProbe(defaults: defaults)
            storage.interval = interval
            #expect(preferences.checkInterval == interval)
            #expect(defaults.object(forKey: "automaticUpdateCheckInterval") as? Int == interval.rawValue)
        }
        for value: Any in [0, -1, 12345, "86400", true, 21600, 43200, 21600.5, 3.5] {
            defaults.set(value, forKey: "automaticUpdateCheckInterval")
            preferences.checkInterval = preferences.checkInterval
            let storage = UpdateIntervalStorageProbe(defaults: defaults)
            #expect(storage.interval == preferences.checkInterval)
            #expect(storage.interval == .daily)
            #expect(defaults.object(forKey: "automaticUpdateCheckInterval") as? Int == 86400)
        }
        #expect(!preferences.automaticChecksEnabled)
    }

    @Test
    func supportedIntervalsUseStableStorageIdentifiers() {
        #expect(UpdateCheckInterval.allCases == [.daily, .weekly, .monthly])
        #expect(UpdateCheckInterval.allCases.map(\.rawValue) == [86400, 604800, 3])
        for interval in UpdateCheckInterval.allCases {
            #expect(interval.id == interval)
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
        for value: Any in [0, -1, 12345, "86400", true, 21600, 43200, 21600.5, 3.5, ["seconds": 86400]] {
            defaults.set(value, forKey: "automaticUpdateCheckInterval")
            #expect(preferences.checkInterval == .daily)
        }
        preferences.checkInterval = .monthly
        #expect(preferences.checkInterval == .monthly)
    }
}
