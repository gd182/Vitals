import Foundation
import Testing

struct UpdateIntervalPolicyTests {
    @Test
    func checksUseTheSelectedIntervalAtItsExactBoundary() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        for interval in UpdateCheckInterval.allCases {
            let almostDue = now.addingTimeInterval(-interval.timeInterval + 1)
            #expect(!UpdateCheckPolicy.shouldCheck(
                enabled: true, lastAttempt: almostDue, interval: interval, now: now
            ))
            #expect(UpdateCheckPolicy.nextCheckDate(
                enabled: true, lastAttempt: almostDue, interval: interval, now: now
            ) == now.addingTimeInterval(1))
            for elapsed in [interval.timeInterval, interval.timeInterval + 1] {
                let attempt = now.addingTimeInterval(-elapsed)
                #expect(UpdateCheckPolicy.shouldCheck(
                    enabled: true, lastAttempt: attempt, interval: interval, now: now
                ))
                #expect(UpdateCheckPolicy.nextCheckDate(
                    enabled: true, lastAttempt: attempt, interval: interval, now: now
                ) == now)
            }
        }
    }

    @Test
    func disabledMissingAndFutureAttemptsKeepTheirMeaning() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        for interval in UpdateCheckInterval.allCases {
            for attempt in [nil, now.addingTimeInterval(-interval.timeInterval), now.addingTimeInterval(60)] {
                #expect(!UpdateCheckPolicy.shouldCheck(
                    enabled: false, lastAttempt: attempt, interval: interval, now: now
                ))
                #expect(UpdateCheckPolicy.nextCheckDate(
                    enabled: false, lastAttempt: attempt, interval: interval, now: now
                ) == nil)
            }
            for attempt in [nil, now.addingTimeInterval(60)] {
                #expect(UpdateCheckPolicy.shouldCheck(
                    enabled: true, lastAttempt: attempt, interval: interval, now: now
                ))
                #expect(UpdateCheckPolicy.nextCheckDate(
                    enabled: true, lastAttempt: attempt, interval: interval, now: now
                ) == now)
            }
        }
    }

    @Test
    func intervalChangesAreMeasuredFromTheLastAttempt() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let attempt = now.addingTimeInterval(-8 * 60 * 60)
        for interval in UpdateCheckInterval.allCases {
            let due = interval.timeInterval <= 8 * 60 * 60
            #expect(UpdateCheckPolicy.shouldCheck(
                enabled: true, lastAttempt: attempt, interval: interval, now: now
            ) == due)
            #expect(UpdateCheckPolicy.nextCheckDate(
                enabled: true, lastAttempt: attempt, interval: interval, now: now
            ) == (due ? now : attempt.addingTimeInterval(interval.timeInterval)))
        }
    }
}
