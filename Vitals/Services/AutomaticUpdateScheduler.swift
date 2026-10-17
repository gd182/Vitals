//
//  AutomaticUpdateScheduler.swift
//  Vitals
//
//  Created by gd182 on 10/15/26.
//

import Foundation

@MainActor
final class AutomaticUpdateScheduler {
    private let checker: UpdateChecker
    private let preferences: UpdatePreferences
    private var timer: Timer?
    private var checkTask: Task<Void, Never>?
    private var checkID: UUID?
    private var timerID: UUID?
    var scheduledCheckDate: Date? {
        timer?.fireDate
    }

    typealias TimerFactory = (
        Date,
        @escaping @Sendable (Timer) -> Void
    ) -> Timer

    private let clock: () -> Date
    private let makeTimer: TimerFactory

    init(
        checker: UpdateChecker,
        preferences: UpdatePreferences,
        clock: @escaping () -> Date = { Date() },
        makeTimer: @escaping TimerFactory = { date, action in
            Timer(
                fire: date,
                interval: 0,
                repeats: false,
                block: action
            )
        }
    ) {
        self.checker = checker
        self.preferences = preferences
        self.clock = clock
        self.makeTimer = makeTimer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        timerID = nil

        checkTask?.cancel()
        checkID = nil
        checkTask = nil
    }

    func checkIfNeeded(
        includePrereleases: Bool,
        now: Date
    ) async {
        guard !Task.isCancelled, !checker.isChecking else {
            return
        }
        guard UpdateCheckPolicy.shouldCheck(
            enabled: preferences.automaticChecksEnabled, 
            lastAttempt: preferences.lastAttempt, 
            now: now
        )else {
            return
        }
        
        preferences.recordAttempt(at: now)

        await checker.checkForUpdates(
            includePrereleases: includePrereleases
        )
    }

    private func runCheck(includePrereleases: Bool) {
        guard checkTask == nil,
            preferences.automaticChecksEnabled,
            !checker.isChecking else {
            return
        }

        let id = UUID()
        checkID = id

        checkTask = Task { [weak self] in
            guard let self else { return }

            await self.checkIfNeeded(
                includePrereleases: includePrereleases,
                now: self.clock()
            )

            guard self.checkID == id else { return }

            self.checkID = nil
            self.checkTask = nil
            self.refresh(includePrereleases: includePrereleases)
        }
    }

    func refresh(includePrereleases: Bool) {
        timer?.invalidate()
        timer = nil
        timerID = nil

        guard preferences.automaticChecksEnabled else {
            stop()
            return
        }

        guard checkTask == nil, !checker.isChecking else {
            return
        }

        let now = clock()
        guard let date = UpdateCheckPolicy.nextCheckDate(
            enabled: preferences.automaticChecksEnabled,
            lastAttempt: preferences.lastAttempt,
            now: now
        ) else {
            return
        }

        if date <= now {
            runCheck(includePrereleases: includePrereleases)
            return
        }

        let id = UUID()
        timerID = id

        let scheduledTimer = makeTimer(date) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.timerID == id else {
                    return
                }

                self.timerID = nil
                self.timer = nil
                self.refresh(includePrereleases: includePrereleases)
            }
        }

        scheduledTimer.tolerance = 60
        timer = scheduledTimer
        RunLoop.main.add(scheduledTimer, forMode: .common)
    }
}