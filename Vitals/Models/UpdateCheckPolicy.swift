//
//  UpdateCheckPolicy.swift
//  Vitals
//
//  Created by gd182 on 10/16/26.
//

import Foundation

nonisolated enum UpdateCheckInterval: Int, CaseIterable, Identifiable {
    case sixHours = 21600
    case twelveHours = 43200
    case daily = 86400
    case weekly = 604800

    var id: Self {
        self
    }

    var timeInterval: TimeInterval {
        TimeInterval(rawValue)
    }
}

nonisolated enum UpdateCheckPolicy {
    static func shouldCheck(
        enabled: Bool,
        lastAttempt: Date?,
        interval: UpdateCheckInterval = .daily,
        now: Date
    ) -> Bool {
        guard enabled else {
            return false
        }
        guard let lastAttempt else {
            return true
        }

        guard lastAttempt <= now else {
            return true
        }

        return now.timeIntervalSince(lastAttempt) >= interval.timeInterval
    }

    static func nextCheckDate(
        enabled: Bool,
        lastAttempt: Date?,
        interval: UpdateCheckInterval = .daily,
        now: Date
    ) -> Date? {
        guard enabled else {
            return nil
        }

        if shouldCheck(
            enabled: enabled,
            lastAttempt: lastAttempt,
            interval: interval,
            now: now
        ) {
            return now
        }

        guard let lastAttempt else {
            return now
        }

        return lastAttempt.addingTimeInterval(interval.timeInterval)
    }
}