//
//  AutomaticUpdateTests.swift
//  VitalsTests
//
//  Created by gd182 on 10/18/26.
//

import Foundation
import Testing

struct AutomaticUpdateTests {
    @Test
    func disabledChecksDoNotRun() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(!UpdateCheckPolicy.shouldCheck(
            enabled: false,
            lastAttempt: nil,
            now: now
        ))

        #expect(!UpdateCheckPolicy.shouldCheck(
            enabled: false,
            lastAttempt: now.addingTimeInterval(-86_401),
            now: now
        ))
    }

    @Test
    func checksRunWhenNoAttemptExists() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(UpdateCheckPolicy.shouldCheck(
            enabled: true,
            lastAttempt: nil,
            now: now
        ))
    }

    @Test
    func checksWaitForFullDay() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(!UpdateCheckPolicy.shouldCheck(
            enabled: true,
            lastAttempt: now.addingTimeInterval(-86_399),
            now: now
        ))

        #expect(UpdateCheckPolicy.shouldCheck(
            enabled: true,
            lastAttempt: now.addingTimeInterval(-86_400),
            now: now
        ))

        #expect(UpdateCheckPolicy.shouldCheck(
            enabled: true,
            lastAttempt: now.addingTimeInterval(-86_401),
            now: now
        ))

        #expect(!UpdateCheckPolicy.shouldCheck(
            enabled: true,
            lastAttempt: now,
            now: now
        ))
    }

    @Test
    func futureTimestampAllowsRecovery() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(UpdateCheckPolicy.shouldCheck(
            enabled: true,
            lastAttempt: now.addingTimeInterval(3600),
            now: now
        ))
    }

    @Test
    @MainActor
    func preferencesPersistValues() throws {
        let suiteName = "VitalsTests.UpdatePreferences.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = UpdatePreferences(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(!preferences.automaticChecksEnabled)
        #expect(preferences.lastAttempt == nil)

        preferences.automaticChecksEnabled = true
        #expect(preferences.automaticChecksEnabled)

        preferences.recordAttempt(at: now)
        #expect(preferences.lastAttempt == now)

        let secondPreferences = UpdatePreferences(defaults: defaults)
        #expect(secondPreferences.automaticChecksEnabled)
        #expect(secondPreferences.lastAttempt == now)

        preferences.automaticChecksEnabled = false
        #expect(!preferences.automaticChecksEnabled)
        #expect(preferences.lastAttempt == now)

        defaults.set("invalid date", forKey: "lastAutomaticUpdateAttempt")
        #expect(preferences.lastAttempt == nil)
    }

    @Test
    @MainActor
    func schedulerRespectsDailyInterval() async throws {
        let suiteName = "VitalsTests.AutomaticSchedule.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = UpdatePreferences(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var requestCount = 0
        var expectedAttempt = now
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: {
            requestCount += 1
            #expect(preferences.lastAttempt == expectedAttempt)
            return []
        })
        let scheduler = AutomaticUpdateScheduler(checker: checker, preferences: preferences)

        await scheduler.checkIfNeeded(includePrereleases: false, now: now)
        #expect(requestCount == 0)
        #expect(preferences.lastAttempt == nil)

        preferences.automaticChecksEnabled = true
        await scheduler.checkIfNeeded(includePrereleases: false, now: now)
        #expect(requestCount == 1)
        #expect(preferences.lastAttempt == now)
        guard case .upToDate = checker.state else {
            Issue.record("Expected upToDate after automatic check")
            return
        }
        #expect(!checker.isChecking)

        await scheduler.checkIfNeeded(includePrereleases: false, now: now)
        #expect(requestCount == 1)
        #expect(preferences.lastAttempt == now)

        await scheduler.checkIfNeeded(
            includePrereleases: false, now: now.addingTimeInterval(86_399)
        )
        #expect(requestCount == 1)
        #expect(preferences.lastAttempt == now)

        let nextDay = now.addingTimeInterval(86_400)
        expectedAttempt = nextDay
        await scheduler.checkIfNeeded(includePrereleases: false, now: nextDay)
        #expect(requestCount == 2)
        #expect(preferences.lastAttempt == nextDay)
    }

    @Test
    @MainActor
    func failedAttemptStillDefersRetry() async throws {
        let suiteName = "VitalsTests.AutomaticFailure.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = UpdatePreferences(defaults: defaults)
        preferences.automaticChecksEnabled = true
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var requestCount = 0
        let checker = UpdateChecker(currentVersion: "0.1.0", fetchReleases: {
            requestCount += 1
            #expect(preferences.lastAttempt == now)
            throw URLError(.notConnectedToInternet)
        })
        let scheduler = AutomaticUpdateScheduler(checker: checker, preferences: preferences)

        await scheduler.checkIfNeeded(includePrereleases: false, now: now)
        #expect(requestCount == 1)
        #expect(preferences.lastAttempt == now)
        guard case .failed(let error) = checker.state else {
            Issue.record("Expected a network error")
            return
        }
        let networkError = try #require(error as? URLError)
        #expect(networkError.code == .notConnectedToInternet)
        #expect(!checker.isChecking)

        await scheduler.checkIfNeeded(
            includePrereleases: false, now: now.addingTimeInterval(60)
        )
        #expect(requestCount == 1)
        #expect(preferences.lastAttempt == now)
    }

    @Test
    func nextCheckDateRespectsPolicy() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(UpdateCheckPolicy.nextCheckDate(
            enabled: false, lastAttempt: nil, now: now
        ) == nil)

        #expect(UpdateCheckPolicy.nextCheckDate(
            enabled: true, lastAttempt: nil, now: now
        ) == now)

        #expect(UpdateCheckPolicy.nextCheckDate(
            enabled: true,
            lastAttempt: now.addingTimeInterval(-3600),
            now: now
        ) == now.addingTimeInterval(82_800))

        #expect(UpdateCheckPolicy.nextCheckDate(
            enabled: true,
            lastAttempt: now.addingTimeInterval(-86_400),
            now: now
        ) == now)

        #expect(UpdateCheckPolicy.nextCheckDate(
            enabled: true,
            lastAttempt: now.addingTimeInterval(3600),
            now: now
        ) == now)
    }

    @Test
    @MainActor
    func timerSchedulingAndCancellation() throws {
        let suiteName = "VitalsTests.Timer.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = UpdatePreferences(defaults: defaults)
        let checker = UpdateChecker(currentVersion: "0.1.0") {
            Issue.record("No request expected before the scheduled date")
            return []
        }
        let scheduler = AutomaticUpdateScheduler(
            checker: checker,
            preferences: preferences
        )
        defer { scheduler.stop() }

        scheduler.refresh(includePrereleases: false)
        #expect(scheduler.scheduledCheckDate == nil)

        let lastAttempt = Date()
        preferences.recordAttempt(at: lastAttempt)
        preferences.automaticChecksEnabled = true
        let expectedDate = lastAttempt.addingTimeInterval(
            UpdateCheckPolicy.interval
        )

        scheduler.refresh(includePrereleases: false)
        #expect(scheduler.scheduledCheckDate == expectedDate)

        scheduler.refresh(includePrereleases: true)
        #expect(scheduler.scheduledCheckDate == expectedDate)

        preferences.automaticChecksEnabled = false
        scheduler.refresh(includePrereleases: false)
        #expect(scheduler.scheduledCheckDate == nil)

        preferences.automaticChecksEnabled = true
        scheduler.refresh(includePrereleases: false)
        #expect(scheduler.scheduledCheckDate == expectedDate)

        scheduler.stop()
        scheduler.stop()
        #expect(scheduler.scheduledCheckDate == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    @MainActor
    func stoppingCancelsActiveRequest() async throws {
        let suiteName = "VitalsTests.Cancellation.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = UpdatePreferences(defaults: defaults)
        preferences.automaticChecksEnabled = true

        let started = AsyncStream<Void>.makeStream()
        let cancelled = AsyncStream<Bool>.makeStream()
        defer {
            started.continuation.finish()
            cancelled.continuation.finish()
        }

        var requestCount = 0
        let checker = UpdateChecker(currentVersion: "0.1.0") {
            requestCount += 1
            started.continuation.yield(())

            do {
                try await Task.sleep(for: .seconds(3600))
                return []
            } catch {
                cancelled.continuation.yield(Task.isCancelled)
                throw error
            }
        }
        let scheduler = AutomaticUpdateScheduler(
            checker: checker,
            preferences: preferences
        )
        defer { scheduler.stop() }

        var starts = started.stream.makeAsyncIterator()
        var cancellations = cancelled.stream.makeAsyncIterator()

        scheduler.refresh(includePrereleases: false)
        let start: Void? = await starts.next()
        #expect(start != nil)
        #expect(checker.isChecking)

        scheduler.refresh(includePrereleases: false)
        #expect(requestCount == 1)

        scheduler.stop()
        let wasCancelled = await cancellations.next()
        #expect(wasCancelled == true)
        #expect(!checker.isChecking)
        #expect(scheduler.scheduledCheckDate == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    @MainActor
    func stoppingDoesNotCancelManualRequest() async throws {
        let suiteName = "VitalsTests.Manual.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = UpdatePreferences(defaults: defaults)
        preferences.automaticChecksEnabled = true

        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer {
            started.continuation.finish()
            release.continuation.finish()
        }

        var requestCount = 0
        let checker = UpdateChecker(currentVersion: "0.1.0") {
            requestCount += 1
            started.continuation.yield(())
            var responses = release.stream.makeAsyncIterator()
            _ = await responses.next()
            #expect(!Task.isCancelled)
            return []
        }
        let scheduler = AutomaticUpdateScheduler(
            checker: checker,
            preferences: preferences
        )
        defer { scheduler.stop() }

        let manualTask = Task {
            await checker.checkForUpdates(includePrereleases: false)
        }
        defer { manualTask.cancel() }

        var starts = started.stream.makeAsyncIterator()
        let start: Void? = await starts.next()
        #expect(start != nil)

        scheduler.refresh(includePrereleases: false)
        scheduler.stop()
        release.continuation.yield(())
        await manualTask.value

        #expect(requestCount == 1)
        #expect(preferences.lastAttempt == nil)
        guard case .upToDate = checker.state else {
            Issue.record("Manual request should finish normally")
            return
        }
    }

    @Test(.timeLimit(.minutes(1)))
    @MainActor
    func timerFiresAndSchedulesNextDay() async throws {
        let suiteName = "VitalsTests.TimerFire.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = UpdatePreferences(defaults: defaults)
        preferences.automaticChecksEnabled = true

        var now = Date().addingTimeInterval(3600)
        preferences.recordAttempt(at: now)
        let firstDate = now.addingTimeInterval(UpdateCheckPolicy.interval)

        var requestCount = 0
        let checker = UpdateChecker(currentVersion: "0.1.0") {
            requestCount += 1
            return []
        }

        var capturedTimer: Timer?
        let scheduled = AsyncStream<Date>.makeStream()
        defer { scheduled.continuation.finish() }

        let scheduler = AutomaticUpdateScheduler(
            checker: checker,
            preferences: preferences,
            clock: { now },
            makeTimer: { date, action in
                let timer = Timer(
                    fire: date,
                    interval: 0,
                    repeats: false,
                    block: action
                )
                capturedTimer = timer
                scheduled.continuation.yield(date)
                return timer
            }
        )
        defer { scheduler.stop() }

        var dates = scheduled.stream.makeAsyncIterator()
        scheduler.refresh(includePrereleases: false)
        let initialDate = await dates.next()
        #expect(initialDate == firstDate)
        #expect(requestCount == 0)

        now = firstDate
        let timer = try #require(capturedTimer)
        timer.fire()

        let nextDate = await dates.next()
        let expectedDate = now.addingTimeInterval(UpdateCheckPolicy.interval)
        #expect(nextDate == expectedDate)
        #expect(scheduler.scheduledCheckDate == expectedDate)
        #expect(preferences.lastAttempt == now)
        #expect(requestCount == 1)
        #expect(!checker.isChecking)
    }
}
