import Foundation
import Testing

@MainActor
struct UpdateCheckerCacheTests {
    private func release(_ tag: String = "0.2.0", prerelease: Bool = false, draft: Bool = false) -> GitHubRelease {
        GitHubRelease(tagName: tag, name: "Vitals \(tag)",
                      htmlUrl: URL(string: "https://github.com/gd182/Vitals/releases")!,
                      body: "## Changes\n- Improved monitoring", isPrerelease: prerelease, isDraft: draft)
    }

    @Test
    func restorationFiltersTheCacheWithoutFetchingOrRecordingASuccessfulCheck() {
        let cases: [(String?, GitHubRelease?, Bool, String?)] = [
            ("0.1.0", release(), false, "0.2.0"),
            ("0.2.0", release(), false, nil),
            ("0.3.0", release(), false, nil),
            (nil, release(), false, nil),
            ("invalid", release(), false, nil),
            ("0.1.0", nil, false, nil),
            ("0.1.0", release("invalid"), false, nil),
            ("0.1.0", release(draft: true), false, nil),
            ("0.1.0", release(prerelease: true), false, nil),
            ("0.1.0", release(prerelease: true), true, "0.2.0")
        ]
        for (current, cached, includePrereleases, expected) in cases {
            var requests = 0
            var successfulChecks = 0
            var writes: [String?] = []
            let checker = UpdateChecker(currentVersion: current,
                recordSuccessfulCheck: { _ in successfulChecks += 1 },
                fetchReleases: { requests += 1; return [] },
                cachedRelease: cached, includePrereleases: includePrereleases,
                recordAvailableRelease: { writes.append($0?.tagName) })
            #expect(checker.availableRelease?.tagName == expected)
            #expect(writes.count == 1)
            #expect(writes.first! == expected)
            #expect(requests == 0 && successfulChecks == 0)
            guard case .idle = checker.state else {
                Issue.record("Restoring a release must not imply a new network check")
                continue
            }
        }
    }

    @Test
    func successfulChecksPersistTheCandidateAndAnEmptyResponseClearsIt() async throws {
        let suite = "VitalsTests.CheckerCache.Success.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        let candidate = release()
        var empty = false
        let checker = UpdateChecker(currentVersion: "0.1.0",
            fetchReleases: { empty ? [] : [candidate] },
            recordAvailableRelease: { preferences.cachedRelease = $0 })
        await checker.checkForUpdates(includePrereleases: false)
        #expect(checker.availableRelease?.tagName == "0.2.0")
        #expect(preferences.cachedRelease?.tagName == "0.2.0")
        #expect(preferences.cachedRelease?.body == candidate.body)
        empty = true
        await checker.checkForUpdates(includePrereleases: false)
        #expect(checker.availableRelease == nil)
        #expect(preferences.cachedRelease == nil)
        #expect(defaults.object(forKey: "cachedUpdateRelease") == nil)
    }

    @Test
    func errorsAndCancellationPreserveTheRestoredCandidateWithoutRewritingIt() async {
        for error: any Error in [URLError(.notConnectedToInternet), CancellationError(), URLError(.cancelled)] {
            let candidate = release()
            var writes: [String?] = []
            let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: { throw error },
                cachedRelease: candidate, recordAvailableRelease: { writes.append($0?.tagName) })
            await checker.checkForUpdates(includePrereleases: false)
            #expect(checker.availableRelease?.tagName == candidate.tagName)
            #expect(writes.count == 1)
            #expect(writes[0] == candidate.tagName)
        }
    }

    @Test
    func resettingClearsThePersistentCandidate() {
        var persisted: GitHubRelease? = release()
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: { [] },
            cachedRelease: persisted, recordAvailableRelease: { persisted = $0 })
        #expect(persisted != nil)
        checker.reset()
        #expect(checker.availableRelease == nil)
        #expect(persisted == nil)
    }
}
