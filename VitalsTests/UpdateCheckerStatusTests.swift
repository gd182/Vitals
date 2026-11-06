import Foundation
import Combine
import Testing

@MainActor
struct UpdateCheckerStatusTests {
    @Test
    func successfulResponsesRecordCompletionTime() async throws {
        let release = GitHubRelease(
            tagName: "0.2.0", name: nil,
            htmlUrl: try #require(URL(string: "https://github.com/gd182/Vitals/releases/tag/0.2.0")),
            body: nil, isPrerelease: false, isDraft: false
        )
        for releases in [[], [release]] {
            let suite = "VitalsTests.CheckStatus.Success.\(UUID())"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let preferences = UpdatePreferences(defaults: defaults)
            let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
            let completedAt = startedAt.addingTimeInterval(5)
            var now = startedAt
            var recorded: [Date] = []
            let checker = UpdateChecker(
                currentVersion: "0.1.0",
                clock: { now },
                recordSuccessfulCheck: {
                    recorded.append($0)
                    preferences.recordSuccessfulCheck(at: $0)
                },
                fetchReleases: {
                    #expect(preferences.lastSuccessfulCheck == nil)
                    now = completedAt
                    return releases
                }
            )
            var successAtStateTransition: Date?
            let observation = checker.$state.sink { state in
                switch state {
                case .upToDate, .updateAvailable:
                    successAtStateTransition = preferences.lastSuccessfulCheck
                default:
                    break
                }
            }
            await checker.checkForUpdates(includePrereleases: false)
            #expect(recorded == [completedAt])
            #expect(preferences.lastSuccessfulCheck == completedAt)
            #expect(successAtStateTransition == completedAt)
            withExtendedLifetime(observation) {}
            #expect(preferences.lastAttempt == nil)
            #expect(!preferences.automaticChecksEnabled)
            if releases.isEmpty {
                guard case .upToDate = checker.state else {
                    Issue.record("Expected upToDate")
                    continue
                }
            } else {
                guard case .updateAvailable = checker.state else {
                    Issue.record("Expected updateAvailable")
                    continue
                }
            }
        }
    }

    @Test
    func unsuccessfulChecksDoNotRecordSuccess() async {
        for scenario in 0..<4 {
            var recorded: [Date] = []
            var clockCalls = 0
            let checker = UpdateChecker(
                currentVersion: scenario == 0 ? nil : "0.1.0",
                clock: {
                    clockCalls += 1
                    return Date(timeIntervalSince1970: 1_700_000_000)
                },
                recordSuccessfulCheck: { recorded.append($0) },
                fetchReleases: {
                    switch scenario {
                    case 1: throw URLError(.notConnectedToInternet)
                    case 2: throw CancellationError()
                    case 3: throw URLError(.cancelled)
                    default: return []
                    }
                }
            )
            await checker.checkForUpdates(includePrereleases: false)
            #expect(recorded.isEmpty)
            #expect(clockCalls == 0)
        }
    }

    @Test
    func cancelledTaskDoesNotRecordAnOtherwiseSuccessfulResponse() async {
        var recorded: [Date] = []
        let checker = UpdateChecker(
            currentVersion: "0.1.0",
            clock: { Date(timeIntervalSince1970: 1_700_000_000) },
            recordSuccessfulCheck: { recorded.append($0) },
            fetchReleases: { [] }
        )
        let task = Task { await checker.checkForUpdates(includePrereleases: false) }
        task.cancel()
        await task.value
        #expect(recorded.isEmpty)
        guard case .idle = checker.state else {
            Issue.record("Expected idle after cancellation")
            return
        }
    }
}
