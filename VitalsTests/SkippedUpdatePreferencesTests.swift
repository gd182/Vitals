import Foundation
import Testing

@MainActor
struct SkippedUpdatePreferencesTests {
    @Test
    func skippedVersionSurvivesReloadCanBeReplacedAndCanBeCleared() throws {
        let suite = "VitalsTests.SkippedUpdate.Persistence.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        #expect(preferences.skippedVersion == nil)
        preferences.skippedVersion = "v0.2.0"
        let reloaded = UpdatePreferences(defaults: try #require(UserDefaults(suiteName: suite)))
        #expect(reloaded.skippedVersion == "v0.2.0")
        reloaded.skippedVersion = "0.3.0"
        #expect(preferences.skippedVersion == "0.3.0")
        reloaded.skippedVersion = nil
        #expect(defaults.object(forKey: "skippedUpdateVersion") == nil)
        #expect(preferences.skippedVersion == nil)
    }

    @Test
    func skippingDoesNotClearTheReleaseOrChangeSchedulingPreferences() throws {
        let suite = "VitalsTests.SkippedUpdate.Independence.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        let release = GitHubRelease(tagName: "0.2.0", name: "Vitals 0.2.0",
            htmlUrl: URL(string: "https://github.com/gd182/Vitals/releases/tag/0.2.0")!,
            body: "## Improvements", isPrerelease: false, isDraft: false)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        preferences.cachedRelease = release
        preferences.recordAttempt(at: date)
        preferences.recordSuccessfulCheck(at: date)
        preferences.checkInterval = .monthly
        preferences.automaticChecksEnabled = true

        for skipped: String? in ["0.2.0", nil] {
            preferences.skippedVersion = skipped
            #expect(preferences.cachedRelease?.tagName == release.tagName)
            #expect(preferences.cachedRelease?.body == release.body)
            #expect(preferences.lastAttempt == date)
            #expect(preferences.lastSuccessfulCheck == date)
            #expect(preferences.checkInterval == .monthly)
            #expect(preferences.automaticChecksEnabled)
        }

        preferences.skippedVersion = "0.2.0"
        preferences.cachedRelease = nil
        #expect(preferences.skippedVersion == "0.2.0")
    }
}
