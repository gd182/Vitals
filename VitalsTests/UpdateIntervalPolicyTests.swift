import Foundation
import Testing

struct UpdateIntervalPolicyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    @Test
    func fixedIntervalsKeepTheirDurations() throws {
        let attempt = try date(2025, 1, 31, calendar: calendar)
        #expect(UpdateCheckInterval.daily.nextDate(after: attempt, calendar: calendar)
                == attempt.addingTimeInterval(86_400))
        #expect(UpdateCheckInterval.weekly.nextDate(after: attempt, calendar: calendar)
                == attempt.addingTimeInterval(604_800))
    }

    @Test
    func monthlyUsesCalendarMonthsAndClampsTheDay() throws {
        for (year, month, day, nextYear, nextMonth, nextDay) in [
            (2025, 1, 31, 2025, 2, 28),
            (2024, 1, 31, 2024, 2, 29),
            (2024, 2, 29, 2024, 3, 29),
            (2025, 3, 31, 2025, 4, 30),
            (2025, 12, 31, 2026, 1, 31)
        ] {
            let attempt = try date(year, month, day, calendar: calendar)
            let expected = try date(nextYear, nextMonth, nextDay, calendar: calendar)
            #expect(UpdateCheckInterval.monthly.nextDate(after: attempt, calendar: calendar) == expected)
        }
        var local = calendar
        local.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let beforeDST = try date(2025, 2, 20, calendar: local)
        let afterDST = try date(2025, 3, 20, calendar: local)
        #expect(UpdateCheckInterval.monthly.nextDate(after: beforeDST, calendar: local) == afterDST)
    }

    @Test
    func checksUseTheSelectedIntervalAtItsExactBoundary() throws {
        let attempt = try date(2025, 1, 31, calendar: calendar)
        for interval in UpdateCheckInterval.allCases {
            let due = try #require(interval.nextDate(after: attempt, calendar: calendar))
            for offset in [-1.0, 0, 1] {
                let now = due.addingTimeInterval(offset)
                #expect(UpdateCheckPolicy.shouldCheck(
                    enabled: true, lastAttempt: attempt, interval: interval, calendar: calendar, now: now
                ) == (offset >= 0))
                #expect(UpdateCheckPolicy.nextCheckDate(
                    enabled: true, lastAttempt: attempt, interval: interval, calendar: calendar, now: now
                ) == (offset < 0 ? due : now))
            }
        }
    }

    @Test
    func disabledMissingAndFutureAttemptsKeepTheirMeaning() throws {
        let now = try date(2025, 2, 15, calendar: calendar)
        for interval in UpdateCheckInterval.allCases {
            for attempt in [nil, now.addingTimeInterval(-3_000_000), now.addingTimeInterval(60)] {
                #expect(!UpdateCheckPolicy.shouldCheck(
                    enabled: false, lastAttempt: attempt, interval: interval, calendar: calendar, now: now
                ))
                #expect(UpdateCheckPolicy.nextCheckDate(
                    enabled: false, lastAttempt: attempt, interval: interval, calendar: calendar, now: now
                ) == nil)
            }
            for attempt in [nil, now.addingTimeInterval(60)] {
                #expect(UpdateCheckPolicy.shouldCheck(
                    enabled: true, lastAttempt: attempt, interval: interval, calendar: calendar, now: now
                ))
                #expect(UpdateCheckPolicy.nextCheckDate(
                    enabled: true, lastAttempt: attempt, interval: interval, calendar: calendar, now: now
                ) == now)
            }
        }
    }

    @Test
    func switchingFromMonthlyToDailyCanMakeTheCheckDueImmediately() throws {
        let attempt = try date(2025, 1, 31, calendar: calendar)
        let now = try date(2025, 2, 15, calendar: calendar)
        let monthDue = try date(2025, 2, 28, calendar: calendar)
        #expect(UpdateCheckPolicy.nextCheckDate(
            enabled: true, lastAttempt: attempt, interval: .monthly, calendar: calendar, now: now
        ) == monthDue)
        #expect(UpdateCheckPolicy.nextCheckDate(
            enabled: true, lastAttempt: attempt, interval: .daily, calendar: calendar, now: now
        ) == now)
    }
}
