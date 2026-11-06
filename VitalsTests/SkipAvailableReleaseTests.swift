import Foundation
import Combine
import Testing

@MainActor
struct SkipAvailableReleaseTests {
    private var release: GitHubRelease {
        GitHubRelease(tagName: "v0.2.0", name: "Vitals 0.2.0",
                      htmlUrl: URL(string: "https://github.com/gd182/Vitals/releases/tag/v0.2.0")!,
                      body: "## Changes", isPrerelease: false, isDraft: false)
    }

    @Test
    func skippingHidesTheOfferButKeepsTheCachedDescription() async {
        let release = release
        var cached: GitHubRelease?
        var skipped: [String?] = []
        var successfulChecks = 0
        let checker = UpdateChecker(currentVersion: "0.1.0",
            recordSuccessfulCheck: { _ in successfulChecks += 1 },
            fetchReleases: { [release] },
            recordAvailableRelease: { cached = $0 },
            recordSkippedVersion: { skipped.append($0) })
        await checker.checkForUpdates(includePrereleases: false)
        checker.skipAvailableRelease()
        #expect(checker.availableRelease == nil)
        #expect(cached?.tagName == release.tagName)
        #expect(cached?.body == release.body)
        #expect(skipped.count == 1 && skipped[0] == release.tagName)
        #expect(successfulChecks == 1)
        guard case .idle = checker.state else {
            Issue.record("Skipping an update must return to idle, not report upToDate")
            return
        }
        checker.skipAvailableRelease()
        #expect(skipped.count == 1)
    }

    @Test
    func noCandidateMeansNothingIsSkipped() {
        var writes = 0
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: { [] },
                                    recordSkippedVersion: { _ in writes += 1 })
        checker.skipAvailableRelease()
        #expect(writes == 0)
    }

    @Test
    func restoredSkippedReleaseStaysCachedAndCanBeShownByAManualCheck() async throws {
        let suite = "VitalsTests.SkipRestore.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        let release = release
        preferences.cachedRelease = release
        preferences.skippedVersion = "0.2.0"
        var requests = 0
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: {
            requests += 1
            return [release]
        }, cachedRelease: preferences.cachedRelease,
           recordAvailableRelease: { preferences.cachedRelease = $0 },
           skippedVersion: preferences.skippedVersion,
           recordSkippedVersion: { preferences.skippedVersion = $0 })
        #expect(checker.availableRelease == nil)
        #expect(requests == 0)
        #expect(preferences.cachedRelease?.body == release.body)
        #expect(preferences.cachedRelease?.tagName == release.tagName)
        #expect(preferences.skippedVersion == "0.2.0")
        guard case .idle = checker.state else {
            Issue.record("Restoration must not imply a fresh successful check")
            return
        }
        await checker.checkForUpdates(includePrereleases: false, mode: .automatic)
        #expect(checker.availableRelease == nil)
        #expect(preferences.cachedRelease?.tagName == release.tagName)
        await checker.checkForUpdates(includePrereleases: false, mode: .manual)
        #expect(checker.availableRelease?.tagName == release.tagName)
        #expect(requests == 2)
        #expect(preferences.skippedVersion == "0.2.0")
    }

    @Test
    func differentOrMalformedSkippedVersionsDoNotHideTheRestoredCandidate() {
        let release = release
        for skipped: String? in [nil, "invalid", "", "0.1.0", "0.3.0"] {
            var cached: GitHubRelease?
            let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: { [] },
                cachedRelease: release, recordAvailableRelease: { cached = $0 }, skippedVersion: skipped)
            #expect(checker.availableRelease?.tagName == release.tagName)
            #expect(cached?.tagName == release.tagName)
        }
    }

    @Test
    func automaticChecksRespectNormalizedSkippedVersionsButManualChecksShowThem() async {
        let release = release
        for skipped: String? in [nil, "invalid", "0.2.0", "v0.2.0"] {
            var cached: GitHubRelease?
            var visibleTags: [String] = []
            let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: { [release] },
                recordAvailableRelease: { cached = $0 }, skippedVersion: skipped)
            let observer = checker.$availableRelease.compactMap { $0?.tagName }
                .sink { visibleTags.append($0) }
            defer { observer.cancel() }
            await checker.checkForUpdates(includePrereleases: false, mode: .automatic)
            if skipped == "0.2.0" || skipped == "v0.2.0" {
                #expect(checker.availableRelease == nil)
                #expect(visibleTags.isEmpty, "A skipped release must never be published temporarily")
                guard case .idle = checker.state else {
                    Issue.record("A skipped update must not be reported as upToDate")
                    continue
                }
            } else {
                #expect(checker.availableRelease?.tagName == release.tagName)
            }
            #expect(cached?.tagName == release.tagName)
            #expect(cached?.body == release.body)
            await checker.checkForUpdates(includePrereleases: false)
            #expect(checker.availableRelease?.tagName == release.tagName)
        }
    }

    @Test
    func aSkipTakesEffectImmediatelyWithoutFallingBackToAnOlderRelease() async {
        let older = release
        let newest = GitHubRelease(tagName: "0.3.0", name: "Vitals 0.3.0",
            htmlUrl: older.htmlUrl, body: "Newer release", isPrerelease: false, isDraft: false)
        let next = GitHubRelease(tagName: "0.4.0", name: "Vitals 0.4.0",
            htmlUrl: older.htmlUrl, body: "Next release", isPrerelease: false, isDraft: false)
        var releases = [older, newest]
        var cached: GitHubRelease?
        var skipped: String?
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: { releases },
            recordAvailableRelease: { cached = $0 }, recordSkippedVersion: { skipped = $0 })
        await checker.checkForUpdates(includePrereleases: false)
        #expect(checker.availableRelease?.tagName == newest.tagName)
        checker.skipAvailableRelease()
        #expect(skipped == newest.tagName)
        await checker.checkForUpdates(includePrereleases: false, mode: .automatic)
        #expect(checker.availableRelease == nil, "Do not offer the older 0.2.0 instead of skipped 0.3.0")
        #expect(cached?.tagName == newest.tagName)
        await checker.checkForUpdates(includePrereleases: false, mode: .manual)
        #expect(checker.availableRelease?.tagName == newest.tagName)
        releases = [next, older, newest]
        await checker.checkForUpdates(includePrereleases: false, mode: .automatic)
        #expect(checker.availableRelease?.tagName == next.tagName)
        #expect(cached?.tagName == next.tagName)
        #expect(skipped == newest.tagName)
    }

    @Test(.timeLimit(.minutes(1)))
    func inFlightChecksCannotBeSkippedOrResetByTheSkipAction() async {
        let release = release
        let started = AsyncStream<Void>.makeStream()
        let response = AsyncStream<Void>.makeStream()
        defer {
            started.continuation.finish()
            response.continuation.finish()
        }
        var writes = 0
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: {
            started.continuation.yield(())
            var iterator = response.stream.makeAsyncIterator()
            _ = await iterator.next()
            return [release]
        }, cachedRelease: release, recordSkippedVersion: { _ in writes += 1 })
        var starts = started.stream.makeAsyncIterator()
        let task = Task { await checker.checkForUpdates(includePrereleases: false) }
        defer { task.cancel() }
        let didStart: Void? = await starts.next()
        #expect(didStart != nil)
        checker.skipAvailableRelease()
        #expect(checker.isChecking)
        #expect(checker.availableRelease?.tagName == release.tagName)
        #expect(writes == 0)
        response.continuation.yield(())
        await task.value
        #expect(checker.availableRelease?.tagName == release.tagName)
    }
}
