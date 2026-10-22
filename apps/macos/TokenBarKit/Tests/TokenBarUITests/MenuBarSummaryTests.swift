import Foundation
import Testing
import TokenBarCore

@testable import TokenBarUI

struct MenuBarSummaryTests {
    let formatter = UsageFormatter(locale: Locale(identifier: "en_US"), timeZone: .gmt)

    private func snapshot(_ limits: [UsageLimit]) -> UsageSnapshot {
        UsageSnapshot(provider: "claude", plan: "Pro", limits: limits, fetchedAt: .now)
    }

    @Test func labelsEveryNumber() {
        let text = MenuBarSummary.text(
            for: snapshot([
                UsageLimit(id: "weekly", window: .weekly, usedFraction: 0.79, resetsAt: nil),
                UsageLimit(id: "session", window: .session, usedFraction: 0.17, resetsAt: nil),
            ]),
            formatter: formatter
        )
        #expect(text == "S 17% | W 79%")
    }

    @Test func ignoresModelSpecificLimits() {
        let text = MenuBarSummary.text(
            for: snapshot([
                UsageLimit(id: "weekly.opus", window: .weekly, scope: "Opus", usedFraction: 0.9, resetsAt: nil),
                UsageLimit(id: "session", window: .session, usedFraction: 0.1, resetsAt: nil),
            ]),
            formatter: formatter
        )
        #expect(text == "S 10%")
    }

    @Test func showsDashForUnknownUsage() {
        let text = MenuBarSummary.text(
            for: snapshot([UsageLimit(id: "monthly", window: .monthly, usedFraction: nil, resetsAt: nil)]),
            formatter: formatter
        )
        #expect(text == "M –")
    }

    @Test func returnsNilWithoutLimits() {
        #expect(MenuBarSummary.text(for: snapshot([]), formatter: formatter) == nil)
    }
}
