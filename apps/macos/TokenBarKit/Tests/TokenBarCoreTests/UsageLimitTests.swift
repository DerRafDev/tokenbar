import Foundation
import Testing

@testable import TokenBarCore

struct UsageLimitTests {
    private let resetDate = Date(timeIntervalSince1970: 1_800_000_000)

    @Test(arguments: [
        (0.0, 0.0),
        (100.0, 1.0),
        (17.0, 0.17),
        (130.0, 1.0),
        (-5.0, 0.0),
    ])
    func convertsAndClampsPercent(percent: Double, expected: Double) {
        let limit = UsageLimit(id: "session", window: .session, usedPercent: percent, resetsAt: nil)
        #expect(limit.usedFraction == expected)
    }

    @Test func keepsMissingUsageDistinctFromZero() {
        let limit = UsageLimit(id: "weekly", window: .weekly, usedFraction: nil, resetsAt: nil)
        #expect(limit.usedFraction == nil)
    }

    @Test func dropsNonFiniteUsage() {
        #expect(UsageLimit(id: "a", window: .daily, usedFraction: .nan, resetsAt: nil).usedFraction == nil)
        #expect(UsageLimit(id: "b", window: .daily, usedFraction: .infinity, resetsAt: nil).usedFraction == nil)
    }

    @Test func detectsExpiredReset() {
        let limit = UsageLimit(id: "session", window: .session, usedFraction: 0.5, resetsAt: resetDate)
        #expect(!limit.hasReset(at: resetDate.addingTimeInterval(-1)))
        #expect(limit.hasReset(at: resetDate))
        #expect(limit.hasReset(at: resetDate.addingTimeInterval(60)))
    }

    @Test func unknownResetNeverExpires() {
        let limit = UsageLimit(id: "session", window: .session, usedFraction: 0.5, resetsAt: nil)
        #expect(!limit.hasReset(at: .distantFuture))
    }

    @Test func snapshotFindsUnscopedLimitByDefault() {
        let snapshot = UsageSnapshot(
            provider: "claude",
            plan: nil,
            limits: [
                UsageLimit(id: "weekly.opus", window: .weekly, scope: "Opus", usedFraction: 0.9, resetsAt: nil),
                UsageLimit(id: "weekly", window: .weekly, usedFraction: 0.3, resetsAt: nil),
            ],
            fetchedAt: resetDate
        )
        #expect(snapshot.limit(.weekly)?.id == "weekly")
        #expect(snapshot.limit(.weekly, scope: "Opus")?.id == "weekly.opus")
        #expect(snapshot.limit(.session) == nil)
    }

    @Test func distinguishesRollingWindowsFromSessionsAndByLength() {
        let fiveHours = LimitWindow.rolling(length: .seconds(5 * 3600))
        #expect(fiveHours != .session)
        #expect(fiveHours != .rolling(length: .seconds(3600)))
        #expect(fiveHours == .rolling(length: .seconds(18_000)))

        let snapshot = UsageSnapshot(
            provider: "codex",
            plan: nil,
            limits: [UsageLimit(id: "rolling", window: fiveHours, usedFraction: 0.1, resetsAt: nil)],
            fetchedAt: resetDate
        )
        #expect(snapshot.limit(.session) == nil)
        #expect(snapshot.limit(fiveHours)?.id == "rolling")
    }
}
