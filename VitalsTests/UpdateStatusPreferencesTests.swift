import Foundation
import Testing

@MainActor
struct UpdateStatusPreferencesTests {
    @Test
    func statusLabelsHaveTranslations() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        for key in ["updates_last_successful_check", "updates_no_successful_check"] {
            let entry = try #require(strings[key] as? [String: Any])
            let translations = try #require(entry["localizations"] as? [String: Any])
            for language in ["en", "ru", "de"] {
                let translation = try #require(translations[language] as? [String: Any])
                let unit = try #require(translation["stringUnit"] as? [String: Any])
                let value = try #require(unit["value"] as? String)
                #expect(unit["state"] as? String == "translated")
                #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(value != key)
                if language == "ru" {
                    #expect(!value.unicodeScalars.contains {
                        (65...90).contains($0.value) || (97...122).contains($0.value)
                    })
                }
            }
        }
    }

    @Test
    func successfulCheckIsInitiallyUnknown() throws {
        let suite = "VitalsTests.UpdateStatus.Defaults.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let attempt = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set(attempt, forKey: "lastAutomaticUpdateAttempt")

        let preferences = UpdatePreferences(defaults: defaults)
        #expect(preferences.lastSuccessfulCheck == nil)
        #expect(preferences.lastAttempt == attempt)
        #expect(!preferences.automaticChecksEnabled)
    }

    @Test
    func successfulChecksPersistIndependentlyOfAttemptsAndOptIn() throws {
        let suite = "VitalsTests.UpdateStatus.Persistence.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        let attempt = Date(timeIntervalSince1970: 1_700_000_000)
        let success = attempt.addingTimeInterval(5)
        preferences.recordAttempt(at: attempt)
        preferences.recordSuccessfulCheck(at: success)

        #expect(preferences.lastSuccessfulCheck == success)
        #expect(defaults.object(forKey: "lastSuccessfulUpdateCheck") as? Date == success)
        #expect(preferences.lastAttempt == attempt)
        #expect(!preferences.automaticChecksEnabled)

        preferences.recordAttempt(at: success.addingTimeInterval(60))
        #expect(preferences.lastSuccessfulCheck == success)
        let reloadedDefaults = try #require(UserDefaults(suiteName: suite))
        let reloaded = UpdatePreferences(defaults: reloadedDefaults)
        #expect(reloaded.lastSuccessfulCheck == success)
        #expect(reloaded.lastAttempt == success.addingTimeInterval(60))

        preferences.automaticChecksEnabled = true
        preferences.automaticChecksEnabled = false
        #expect(preferences.lastSuccessfulCheck == success)
        let nextSuccess = success.addingTimeInterval(120)
        preferences.recordSuccessfulCheck(at: nextSuccess)
        #expect(preferences.lastSuccessfulCheck == nextSuccess)
        #expect(preferences.lastAttempt == success.addingTimeInterval(60))
    }

    @Test
    func malformedSuccessfulCheckValuesAreIgnored() throws {
        let suite = "VitalsTests.UpdateStatus.Invalid.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        for value: Any in ["invalid date", 123, true, ["timestamp": 123]] {
            defaults.set(value, forKey: "lastSuccessfulUpdateCheck")
            #expect(preferences.lastSuccessfulCheck == nil)
        }
        let success = Date(timeIntervalSince1970: 1_700_000_000)
        preferences.recordSuccessfulCheck(at: success)
        #expect(preferences.lastSuccessfulCheck == success)
    }
}
