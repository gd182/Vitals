//
//  UpdateCheckPolicy.swift
//  Vitals
//
//  Created by gd182 on 10/16/26.
//

import Foundation

nonisolated enum UpdateCheckInterval: Int, CaseIterable, Identifiable {
    case daily = 86400
    case weekly = 604800
    case monthly = 3

    var id: Self {
        self
    }

    func nextDate(
        after date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        switch self {
        case .daily:
            return date.addingTimeInterval(86_400)
        case .weekly:
            return date.addingTimeInterval(604_800)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }

    var titleKey: String {
        switch self {
        case .daily:
            return "updates_interval_daily"
        case .weekly:
            return "updates_interval_weekly"
        case .monthly:
            return "updates_interval_monthly"
        }
    }
}

nonisolated enum UpdateCheckPolicy {
    static func shouldCheck(
        enabled: Bool,
        lastAttempt: Date?,
        interval: UpdateCheckInterval = .daily,
        calendar: Calendar = .current,
        now: Date
    ) -> Bool {
        guard let date = nextCheckDate(
            enabled: enabled,
            lastAttempt: lastAttempt,
            interval: interval,
            calendar: calendar,
            now: now
        ) else {
            return false
        }
        return date <= now
    }

    static func nextCheckDate(
        enabled: Bool,
        lastAttempt: Date?,
        interval: UpdateCheckInterval = .daily,
        calendar: Calendar = .current,
        now: Date
    ) -> Date? {
        guard enabled else {
            return nil
        }

        guard let lastAttempt, lastAttempt <= now else {
            return now
        }

        guard let dueDate = interval.nextDate(after: lastAttempt, calendar: calendar) else {
            return nil
        }
        return max(dueDate, now)
    }
}