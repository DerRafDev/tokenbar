import Foundation
import Testing
import TokenBarCore

@testable import TokenBarUI

struct MenuBarSummaryTests {
    let formatter = UsageFormatter(locale: Locale(identifier: "en_US"), timeZone: .gmt)

    private func snapshot(_ limits: [UsageLimit]) -> UsageSnapshot {
        UsageSnapshot(provider: "claude", plan: "Pro", limits: limits, fetchedAt: .now)
    }

    private let sessionAndWeek = [
        UsageLimit(id: "session", window: .session, usedFraction: 0.42, resetsAt: nil),
        UsageLimit(id: "weekly", window: .weekly, usedFraction: 0.61, resetsAt: nil),
    ]

    @Test func providersModeShowsCurrentSessionEvenWhenWeekIsHigher() {
        #expect(MenuBarSummary.text(for: snapshot(sessionAndWeek), mode: .providers, formatter: formatter) == "42%")
    }

    @Test func detailedModeShowsFirstTwoLimitsInProviderOrder() {
        let text = MenuBarSummary.text(
            for: snapshot(
                sessionAndWeek + [UsageLimit(id: "monthly", window: .monthly, usedFraction: 1, resetsAt: nil)]),
            mode: .detailed,
            formatter: formatter
        )
        #expect(text == "42/61")
    }

    @Test func detailedModeKeepsUnitForSingleLimit() {
        let text = MenuBarSummary.text(
            for: snapshot([UsageLimit(id: "monthly", window: .monthly, usedFraction: 0.3, resetsAt: nil)]),
            mode: .detailed,
            formatter: formatter
        )
        #expect(text == "30%")
    }

    @Test func ignoresModelSpecificLimits() {
        let limits = [
            UsageLimit(id: "weekly.opus", window: .weekly, scope: "Opus", usedFraction: 0.9, resetsAt: nil),
            UsageLimit(id: "session", window: .session, usedFraction: 0.1, resetsAt: nil),
        ]
        #expect(MenuBarSummary.text(for: snapshot(limits), mode: .providers, formatter: formatter) == "10%")
        #expect(MenuBarSummary.level(of: snapshot(limits), mode: .providers) == .normal)
    }

    @Test func usesModelSpecificLimitsWhenThereAreNoOthers() {
        let limits = [UsageLimit(id: "weekly.opus", window: .weekly, scope: "Opus", usedFraction: 0.2, resetsAt: nil)]
        #expect(MenuBarSummary.text(for: snapshot(limits), mode: .providers, formatter: formatter) == "20%")
    }

    @Test func showsDashForUnknownUsage() {
        let text = MenuBarSummary.text(
            for: snapshot([UsageLimit(id: "monthly", window: .monthly, usedFraction: nil, resetsAt: nil)]),
            mode: .providers,
            formatter: formatter
        )
        #expect(text == "–")
    }

    @Test func returnsNilWithoutLimits() {
        #expect(MenuBarSummary.text(for: snapshot([]), mode: .providers, formatter: formatter) == nil)
    }

    @Test func levelFollowsShownValues() {
        let limits = [
            UsageLimit(id: "session", window: .session, usedFraction: 0.75, resetsAt: nil),
            UsageLimit(id: "weekly", window: .weekly, usedFraction: 0.95, resetsAt: nil),
        ]
        #expect(MenuBarSummary.level(of: snapshot(limits), mode: .providers) == .attention)
        #expect(MenuBarSummary.level(of: snapshot(limits), mode: .detailed) == .critical)
        #expect(MenuBarSummary.level(of: snapshot(sessionAndWeek), mode: .detailed) == .normal)
    }

    @Test func fallsBackToMoreCompactModes() {
        #expect(MenuBarSummary.fallbacks(for: .detailed) == [.detailed, .providers, .minimal])
        #expect(MenuBarSummary.fallbacks(for: .providers) == [.providers, .minimal])
        #expect(MenuBarSummary.fallbacks(for: .minimal) == [.minimal])
    }

    @MainActor
    @Test func minimalModeShowsOnlyProviderWithBusiestSession() {
        let claude = ProviderDescriptor(id: "claude", displayName: "Claude")
        let gemini = ProviderDescriptor(id: "gemini", displayName: "Gemini")
        let codex = ProviderDescriptor(id: "codex", displayName: "Codex")
        let items = MenuBarLabel.items(
            for: [
                (claude, snapshot([UsageLimit(id: "session", window: .session, usedFraction: 0.15, resetsAt: nil)])),
                (gemini, snapshot(sessionAndWeek)),
                (codex, snapshot([UsageLimit(id: "session", window: .session, usedFraction: 0.61, resetsAt: nil)])),
            ],
            mode: .minimal,
            formatter: formatter
        )
        // Gemini's week (61%) is higher, but only sessions are compared.
        #expect(items.map(\.id) == ["codex"])
        #expect(items.first?.values == ["61%"])
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

struct UsageLevelTests {
    @Test(
        arguments: [
            (nil, UsageLevel.normal),
            (0.0, .normal),
            (0.69, .normal),
            (0.7, .attention),
            (0.89, .attention),
            (0.9, .critical),
            (1.0, .critical),
        ] as [(Double?, UsageLevel)])
    func classifiesUsage(fraction: Double?, expected: UsageLevel) {
        #expect(UsageLevel(fraction) == expected)
    }

    private func snapshot(_ limits: [UsageLimit]) -> UsageSnapshot {
        UsageSnapshot(provider: "claude", plan: nil, limits: limits, fetchedAt: .now)
    }

    @Test func headlineIsTheCurrentSession() {
        let limits = [
            UsageLimit(id: "session", window: .session, usedFraction: 0.3, resetsAt: nil),
            UsageLimit(id: "weekly", window: .weekly, usedFraction: 0.8, resetsAt: nil),
            UsageLimit(id: "weekly.opus", window: .weekly, scope: "Opus", usedFraction: 0.9, resetsAt: nil),
        ]
        #expect(snapshot(limits).headlineLimit?.id == "session")
    }

    @Test func headlineSkipsLimitsWithoutPercentage() {
        let limits = [
            UsageLimit(id: "session", window: .session, usedFraction: nil, resetsAt: nil),
            UsageLimit(id: "weekly", window: .weekly, usedFraction: 0.3, resetsAt: nil),
        ]
        #expect(snapshot(limits).headlineLimit?.id == "weekly")
    }
}
