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
        let path = Bundle.tokenBarUI.path(forResource: "pt-BR", ofType: "lproj")!
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
}
