import Foundation
import Testing
import TokenBarCore

@testable import TokenBarUI

struct UsageFormatterTests {
    // Thursday, 2026-10-22 16:20 in São Paulo (UTC-3).
    let now = Date(timeIntervalSince1970: 1_792_696_800)
    let saoPaulo = TimeZone(identifier: "America/Sao_Paulo")!
    var english: UsageFormatter { UsageFormatter(locale: Locale(identifier: "en_US"), timeZone: saoPaulo) }
    var portuguese: UsageFormatter {
        // SwiftPM's native build system lowercases the folder name; Swift Build and Xcode keep it.
        let path = ["pt-BR", "pt-br"].lazy.compactMap { Bundle.tokenBarUI.path(forResource: $0, ofType: "lproj") }
            .first!
        return UsageFormatter(locale: Locale(identifier: "pt_BR"), timeZone: saoPaulo, strings: Bundle(path: path)!)
    }

    /// Date formatting uses narrow no-break spaces (for example before "PM"); compare with plain spaces.
    private func normalized(_ string: String?) -> String? {
        string?.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    @Test(arguments: [
        (0.0, "0%"),
        (0.004, "<1%"),
        (0.17, "17%"),
        (0.996, "99%"),
        (1.0, "100%"),
    ])
    func formatsPercent(fraction: Double, expected: String) {
        #expect(english.percent(fraction) == expected)
    }

    @Test func formatsUnknownPercent() {
        #expect(english.percent(nil) == "–")
    }

    static let countdowns: [(TimeInterval, String)] = [
        (30, "<1m"),
        (2_700, "45m"),  // 45m
        (10_259, "2h 50m"),  // 2h 50m 59s
        (226_740, "2d 14h"),  // 2d 14h 59m
        (-10, "<1m"),
    ]

    @Test(arguments: countdowns)
    func truncatesCountdown(interval: TimeInterval, expected: String) {
        #expect(english.countdown(interval) == expected)
    }

    @Test func spellsOutWindowLength() {
        #expect(english.duration(5 * 3600) == "5 hours")
        #expect(english.duration(7 * 86400) == "7 days")
        #expect(portuguese.duration(5 * 3600) == "5 horas")
    }

    @Test func describesResetWithinADay() {
        let reset = now.addingTimeInterval(2 * 3600 + 50 * 60)
        #expect(normalized(english.resetDescription(reset, now: now)) == "Resets at 7:10 PM (in 2h 50m)")
        #expect(portuguese.resetDescription(reset, now: now) == "Redefine às 19:10 (em 2h 50min)")
    }

    @Test func describesResetDaysAway() {
        let reset = now.addingTimeInterval(2 * 86400 + 14 * 3600 + 40 * 60)  // Sun 07:00
        #expect(normalized(english.resetDescription(reset, now: now)) == "Resets in 2d 14h (Sun, Oct 25 at 7:00 AM)")
        #expect(portuguese.resetDescription(reset, now: now)?.hasPrefix("Redefine em ") == true)
    }

    @Test func countsRealTimeAcrossDaylightSavingChange() {
        // New York falls back at 02:00 EDT on 2026-11-01: 00:30 EDT to 03:00 EST is 3h 30m, not 2h 30m.
        let newYork = UsageFormatter(
            locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "America/New_York")!)
        let now = Date(timeIntervalSince1970: 1_793_507_400)  // 2026-11-01 04:30 UTC
        let reset = Date(timeIntervalSince1970: 1_793_520_000)  // 2026-11-01 08:00 UTC
        #expect(normalized(newYork.resetDescription(reset, now: now)) == "Resets at 3:00 AM (in 3h 30m)")
    }

    @Test func describesExpiredReset() {
        #expect(english.resetDescription(now, now: now) == "Reset due, updating soon")
        #expect(english.resetDescription(now.addingTimeInterval(-60), now: now) == "Reset due, updating soon")
    }

    @Test func omitsUnknownReset() {
        #expect(english.resetDescription(nil, now: now) == nil)
    }

    @Test func usesTimeZoneOfFormatter() {
        let reset = now.addingTimeInterval(3600)  // 17:20 in São Paulo, 20:20 UTC
        let utc = UsageFormatter(locale: Locale(identifier: "pt_BR"), timeZone: .gmt)
        #expect(portuguese.resetDescription(reset, now: now)?.contains("17:20") == true)
        #expect(utc.resetDescription(reset, now: now)?.contains("20:20") == true)
    }

    @Test func describesLastUpdate() {
        #expect(english.updatedDescription(nil, now: now) == "Not updated yet")
        #expect(english.updatedDescription(now.addingTimeInterval(-30), now: now) == "Updated just now")
        #expect(english.updatedDescription(now.addingTimeInterval(-90), now: now) == "Updated 1m ago")
        #expect(portuguese.updatedDescription(now.addingTimeInterval(-90), now: now) == "Atualizado há 1min")
    }

    @Test func namesLimitsByWindowAndScope() {
        let session = UsageLimit(id: "session", window: .session, usedFraction: 0.1, resetsAt: nil)
        let opus = UsageLimit(id: "weekly.opus", window: .weekly, scope: "Opus", usedFraction: 0.1, resetsAt: nil)
        let rolling = UsageLimit(
            id: "rolling", window: .rolling(length: .seconds(5 * 3600)), usedFraction: 0.1, resetsAt: nil)
        #expect(english.title(for: session) == "Current session")
        #expect(english.title(for: opus) == "Weekly · Opus")
        #expect(english.title(for: rolling) == "Rolling window (5 hours)")
        #expect(portuguese.title(for: session) == "Sessão atual")
        #expect(portuguese.title(for: opus) == "Uso semanal · Opus")
    }

    @Test func namesLimitsShortlyForCompactLists() {
        let session = UsageLimit(id: "session", window: .session, usedFraction: 0.1, resetsAt: nil)
        let opus = UsageLimit(id: "weekly.opus", window: .weekly, scope: "Opus", usedFraction: 0.1, resetsAt: nil)
        let rolling = UsageLimit(
            id: "rolling", window: .rolling(length: .seconds(5 * 3600)), usedFraction: 0.1, resetsAt: nil)
        let monthly = UsageLimit(id: "monthly", window: .monthly, usedFraction: 0.1, resetsAt: nil)
        #expect(english.shortTitle(for: session) == "Session")
        #expect(english.shortTitle(for: opus) == "Week · Opus")
        #expect(english.shortTitle(for: rolling) == "5h")
        #expect(portuguese.shortTitle(for: session) == "Sessão")
        #expect(portuguese.shortTitle(for: monthly) == "Mês")
    }

    @Test(arguments: [(nil, "–"), (0.0, "0"), (0.004, "<1"), (0.996, "99")] as [(Double?, String)])
    func formatsPercentNumber(fraction: Double?, expected: String) {
        #expect(english.percentNumber(fraction) == expected)
    }

    @Test func describesUsageForVoiceOver() {
        #expect(english.usedDescription(0.17) == "17% used")
        #expect(portuguese.usedDescription(0.17) == "17% usado")
    }

    @Test func formatsClockTimeInTheConfiguredTimeZone() {
        #expect(portuguese.time(now) == "16:20")
        #expect(normalized(english.time(now)) == "4:20 PM")
    }
}
