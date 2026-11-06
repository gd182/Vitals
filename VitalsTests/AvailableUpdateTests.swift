import Foundation
import Testing

@MainActor
struct AvailableUpdateTests {
    @Test
    func releaseNotesControlsHaveTranslations() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        for key in ["updates_release_notes", "updates_no_release_notes",
                    "updates_release_notes_close", "updates_open_release", "updates_skip_version"] {
            let entry = try #require(strings[key] as? [String: Any])
            let translations = try #require(entry["localizations"] as? [String: Any])
            for language in ["en", "ru", "de"] {
                let translation = try #require(translations[language] as? [String: Any])
                let unit = try #require(translation["stringUnit"] as? [String: Any])
                let value = try #require(unit["value"] as? String)
                #expect(unit["state"] as? String == "translated")
                #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(value != key)
            }
        }
    }

    private func release() throws -> GitHubRelease {
        GitHubRelease(
            tagName: "0.2.0", name: "Vitals 0.2.0",
            htmlUrl: try #require(URL(string: "https://github.com/gd182/Vitals/releases/tag/0.2.0")),
            body: "## Changes\n- Improved monitoring",
            isPrerelease: false, isDraft: false
        )
    }

    @Test
    func availableReleaseSurvivesErrorsAndCancellationButNotASuccessfulEmptyResponse() async throws {
        let update = try release()
        var outcome = 0
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: {
            switch outcome {
            case 1: throw URLError(.notConnectedToInternet)
            case 2: throw CancellationError()
            case 3: return []
            default: return [update]
            }
        })
        #expect(checker.availableRelease == nil)
        await checker.checkForUpdates(includePrereleases: false)
        #expect(checker.availableRelease?.tagName == update.tagName)
        #expect(checker.availableRelease?.body == update.body)
        outcome = 1
        await checker.checkForUpdates(includePrereleases: false)
        #expect(checker.availableRelease?.tagName == update.tagName)
        guard case .failed = checker.state else {
            Issue.record("Expected failed request state without forgetting the known update")
            return
        }
        outcome = 2
        await checker.checkForUpdates(includePrereleases: false)
        #expect(checker.availableRelease?.tagName == update.tagName)
        outcome = 3
        await checker.checkForUpdates(includePrereleases: false)
        #expect(checker.availableRelease == nil)
        guard case .upToDate = checker.state else {
            Issue.record("Expected upToDate after a successful empty response")
            return
        }
    }

    @Test
    func resettingTheCheckClearsTheKnownRelease() async throws {
        let update = try release()
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: { [update] })
        await checker.checkForUpdates(includePrereleases: false)
        #expect(checker.availableRelease != nil)
        checker.reset()
        #expect(checker.availableRelease == nil)
        guard case .idle = checker.state else {
            Issue.record("Expected idle after resetting the update selection")
            return
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func checkingAndCancellingDoNotTemporarilyRemoveTheKnownRelease() async throws {
        let update = try release()
        let started = AsyncStream<Void>.makeStream()
        let releaseResponse = AsyncStream<Void>.makeStream()
        defer {
            started.continuation.finish()
            releaseResponse.continuation.finish()
        }
        var held = false
        var requests = 0
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: {
            requests += 1
            if held {
                started.continuation.yield(())
                var permission = releaseResponse.stream.makeAsyncIterator()
                _ = await permission.next()
                return []
            }
            return [update]
        })
        await checker.checkForUpdates(includePrereleases: false)
        held = true
        var starts = started.stream.makeAsyncIterator()
        let task = Task { await checker.checkForUpdates(includePrereleases: false) }
        defer { task.cancel() }
        let didStart: Void? = await starts.next()
        #expect(didStart != nil)
        #expect(checker.isChecking)
        #expect(checker.availableRelease?.tagName == update.tagName)
        checker.reset()
        #expect(checker.isChecking)
        #expect(checker.availableRelease?.tagName == update.tagName)
        await checker.checkForUpdates(includePrereleases: false)
        #expect(requests == 2)
        task.cancel()
        releaseResponse.continuation.yield(())
        await task.value
        #expect(checker.availableRelease?.tagName == update.tagName)
        #expect(!checker.isChecking)
    }
}
