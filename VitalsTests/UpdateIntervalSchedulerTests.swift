import Foundation
import Testing

@MainActor
struct UpdateIntervalSchedulerTests {
    @Test
    func requestsRespectEveryConfiguredInterval() async throws {
        for interval in UpdateCheckInterval.allCases {
            let suite = "VitalsTests.IntervalScheduler.Boundary.\(UUID())"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let preferences = UpdatePreferences(defaults: defaults)
            preferences.checkInterval = interval
            preferences.automaticChecksEnabled = true
            let attempt = Date(timeIntervalSince1970: 1_700_000_000)
            let due = try #require(interval.nextDate(after: attempt))
            let now = due.addingTimeInterval(-1)
            preferences.recordAttempt(at: attempt)
            var requests = 0
            let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: {
                requests += 1
                return []
            })
            let scheduler = AutomaticUpdateScheduler(checker: checker, preferences: preferences)
            defer { scheduler.stop() }
            await scheduler.checkIfNeeded(includePrereleases: false, now: now)
            #expect(requests == 0)
            #expect(preferences.lastAttempt == attempt)
            await scheduler.checkIfNeeded(includePrereleases: false, now: now.addingTimeInterval(1))
            #expect(requests == 1)
            #expect(preferences.lastAttempt == now.addingTimeInterval(1))
            await scheduler.checkIfNeeded(includePrereleases: false, now: now.addingTimeInterval(1))
            #expect(requests == 1)
        }
    }

    @Test
    func changingIntervalsReplacesTheTimerWithoutChangingTheAttempt() throws {
        let suite = "VitalsTests.IntervalScheduler.Timer.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        preferences.automaticChecksEnabled = true
        let now = Date().addingTimeInterval(3600)
        preferences.recordAttempt(at: now)
        var timers: [Timer] = []
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: {
            Issue.record("No request should run before the timer is due")
            return []
        })
        let scheduler = AutomaticUpdateScheduler(
            checker: checker, preferences: preferences, clock: { now },
            makeTimer: { date, action in
                let timer = Timer(fire: date, interval: 0, repeats: false, block: action)
                timers.append(timer)
                return timer
            }
        )
        defer { scheduler.stop() }
        for interval in [UpdateCheckInterval.daily, .weekly, .monthly, .daily] {
            let previous = timers.last
            preferences.checkInterval = interval
            scheduler.refresh(includePrereleases: false)
            #expect(scheduler.scheduledCheckDate == interval.nextDate(after: now))
            #expect(preferences.lastAttempt == now)
            #expect(timers.last?.isValid == true)
            if let previous { #expect(!previous.isValid) }
        }
        #expect(timers.count == 4)
        preferences.automaticChecksEnabled = false
        scheduler.refresh(includePrereleases: false)
        #expect(scheduler.scheduledCheckDate == nil)
        #expect(timers.allSatisfy { !$0.isValid })
    }

    @Test(.timeLimit(.minutes(1)))
    func intervalChangesDuringARequestApplyAfterItFinishes() async throws {
        let suite = "VitalsTests.IntervalScheduler.InFlight.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UpdatePreferences(defaults: defaults)
        preferences.automaticChecksEnabled = true
        preferences.checkInterval = .weekly
        let now = Date().addingTimeInterval(3600)
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let scheduled = AsyncStream<Date>.makeStream()
        defer {
            started.continuation.finish()
            release.continuation.finish()
            scheduled.continuation.finish()
        }
        var requests = 0
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: {
            requests += 1
            started.continuation.yield(())
            var permission = release.stream.makeAsyncIterator()
            _ = await permission.next()
            return []
        })
        let scheduler = AutomaticUpdateScheduler(
            checker: checker, preferences: preferences, clock: { now },
            makeTimer: { date, action in
                scheduled.continuation.yield(date)
                return Timer(fire: date, interval: 0, repeats: false, block: action)
            }
        )
        defer { scheduler.stop() }
        var starts = started.stream.makeAsyncIterator()
        var dates = scheduled.stream.makeAsyncIterator()
        scheduler.refresh(includePrereleases: false)
        let firstStart: Void? = await starts.next()
        #expect(firstStart != nil)
        #expect(checker.isChecking)
        preferences.checkInterval = .daily
        scheduler.refresh(includePrereleases: false)
        #expect(scheduler.scheduledCheckDate == nil)
        #expect(requests == 1)
        release.continuation.yield(())
        let nextDate = await dates.next()
        #expect(nextDate == now.addingTimeInterval(86_400))
        #expect(scheduler.scheduledCheckDate == nextDate)
        #expect(requests == 1)
        #expect(preferences.lastAttempt == now)
    }
}
