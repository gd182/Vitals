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
    static let interval: TimeInterval = 24 * 60 * 60

    static func shouldCheck(
        enabled: Bool,
        lastAttempt: Date?,
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

        return now.timeIntervalSince(lastAttempt) >= interval
    }

    static func nextCheckDate(
        enabled: Bool,
        lastAttempt: Date?,
        now: Date
    ) -> Date? {
        guard enabled else {
            return nil
        }

        if shouldCheck(
            enabled: enabled,
            lastAttempt: lastAttempt,
            now: now
        ) {
            return now
        }

        guard let lastAttempt else {
            return now
        }

        return lastAttempt.addingTimeInterval(interval)
    }
}