import Foundation
import Testing
import TokenBarCore

@testable import TokenBarUI

struct MenuBarSummaryTests {
    let formatter = UsageFormatter(locale: Locale(identifier: "en_US"), timeZone: .gmt)

    private func snapshot(_ limits: [UsageLimit]) -> UsageSnapshot {
        UsageSnapshot(provider: "claude", plan: "Pro", limits: limits, fetchedAt: .now)
    }

    @Test func labelsEveryNumberInProviderOrder() {
        let text = MenuBarSummary.text(
            for: snapshot([
                UsageLimit(id: "session", window: .session, usedFraction: 0.17, resetsAt: nil),
                UsageLimit(id: "weekly", window: .weekly, usedFraction: 0.79, resetsAt: nil),
            ]),
            formatter: formatter
        )
        #expect(text == "S 17% | W 79%")
    }

    @Test func labelsRollingWindowByLengthNotAsSession() {
        let text = MenuBarSummary.text(
            for: snapshot([
                UsageLimit(
                    id: "rolling", window: .rolling(length: .seconds(5 * 3600)), usedFraction: 0.12, resetsAt: nil),
                UsageLimit(id: "weekly", window: .weekly, usedFraction: 0.42, resetsAt: nil),
            ]),
            formatter: formatter
        )
        #expect(text == "5h 12% | W 42%")
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

    @Test func splitsEachNumberFromItsLabel() {
        let parts = MenuBarSummary.parts(
            for: snapshot([
                UsageLimit(id: "session", window: .session, usedFraction: 0.17, resetsAt: nil),
                UsageLimit(id: "weekly", window: .weekly, usedFraction: 0.79, resetsAt: nil),
            ]),
            formatter: formatter
        )
        #expect(parts == [.init(label: "S", value: "17%"), .init(label: "W", value: "79%")])
    }

    @Test func spellsOutLimitsForVoiceOver() {
        let text = MenuBarSummary.spokenText(
            for: snapshot([
                UsageLimit(id: "session", window: .session, usedFraction: 0.17, resetsAt: nil),
                UsageLimit(id: "weekly", window: .weekly, usedFraction: 0.79, resetsAt: nil),
                UsageLimit(id: "weekly.opus", window: .weekly, scope: "Opus", usedFraction: 0.9, resetsAt: nil),
            ]),
            name: "Claude",
            formatter: formatter
        )
        #expect(text == "Claude: Current session, 17% used; Weekly, 79% used")
    }
}
