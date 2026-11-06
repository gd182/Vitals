import Foundation
import Testing

@MainActor
struct UpdateReleaseCacheTests {
    private func release(tag: String = "0.2.0", hasDescription: Bool = true) throws -> GitHubRelease {
        GitHubRelease(tagName: tag, name: hasDescription ? "Vitals — обновление" : nil,
                      htmlUrl: try #require(URL(string: "https://github.com/gd182/Vitals/releases/tag/\(tag)")),
                      body: hasDescription ? "## Changes\n\n- **Исправлено**\n- Verbesserungen 🚀" : nil,
                      isPrerelease: tag.contains("beta"), isDraft: false)
    }

    @Test
    func releaseSurvivesReloadWithAllFieldsAndWithoutChangingScheduling() throws {
        let suite = "VitalsTests.ReleaseCache.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        preferences.checkInterval = .monthly
        preferences.recordAttempt(at: date)
        preferences.recordSuccessfulCheck(at: date)
        #expect(preferences.cachedRelease == nil)

        let expected = try release(tag: "0.2.0-beta.1")
        preferences.cachedRelease = expected
        let reopened = UpdatePreferences(defaults: try #require(UserDefaults(suiteName: suite)))
        let actual = try #require(reopened.cachedRelease)
        #expect(actual.tagName == expected.tagName)
        #expect(actual.name == expected.name)
        #expect(actual.htmlUrl == expected.htmlUrl)
        #expect(actual.body == expected.body)
        #expect(actual.isPrerelease == expected.isPrerelease)
        #expect(actual.isDraft == expected.isDraft)
        #expect(!reopened.automaticChecksEnabled)
        #expect(reopened.checkInterval == .monthly)
        #expect(reopened.lastAttempt == date)
        #expect(reopened.lastSuccessfulCheck == date)

        reopened.cachedRelease = nil
        #expect(defaults.object(forKey: "cachedUpdateRelease") == nil)
        #expect(preferences.cachedRelease == nil)
        #expect(preferences.lastSuccessfulCheck == date)
        #expect(preferences.lastAttempt == date)
    }

    @Test
    func replacingReleasePreservesOptionalFields() throws {
        let suite = "VitalsTests.ReleaseCache.Replace.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        preferences.cachedRelease = try release()
        preferences.cachedRelease = try release(tag: "0.3.0", hasDescription: false)
        let actual = try #require(preferences.cachedRelease)
        #expect(actual.tagName == "0.3.0")
        #expect(actual.name == nil)
        #expect(actual.body == nil)
        #expect(!actual.isPrerelease)
    }

    @Test
    func corruptJSONIsRemovedAndCanBeReplaced() throws {
        let suite = "VitalsTests.ReleaseCache.Corrupt.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        for payload in ["not JSON", "null", "[]", "{}", #"{"tag_name":123}"#] {
            defaults.set(Data(payload.utf8), forKey: "cachedUpdateRelease")
            #expect(preferences.cachedRelease == nil)
            #expect(defaults.object(forKey: "cachedUpdateRelease") == nil)
        }
        preferences.cachedRelease = try release()
        #expect(preferences.cachedRelease?.tagName == "0.2.0")
    }

    @Test
    func incorrectStorageTypesDoNotCrashOrChangeOtherPreferences() throws {
        let suite = "VitalsTests.ReleaseCache.Types.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        preferences.checkInterval = .weekly
        for value: Any in [42, true, ["body": "Invalid storage"]] {
            defaults.set(value, forKey: "cachedUpdateRelease")
            #expect(preferences.cachedRelease == nil)
            #expect(preferences.checkInterval == .weekly)
            #expect(!preferences.automaticChecksEnabled)
        }
    }
}
