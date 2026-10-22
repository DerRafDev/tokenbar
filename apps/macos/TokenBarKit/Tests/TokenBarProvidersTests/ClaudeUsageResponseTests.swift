import Foundation
import Testing
import TokenBarCore

@testable import TokenBarProviders

struct ClaudeUsageResponseTests {
    private func date(_ string: String) -> Date {
        try! Date.ISO8601FormatStyle().parse(string)
    }

    @Test func mapsLiveProResponse() throws {
        let limits = try ClaudeUsageResponse.decode(Fixture.data("usage-pro")).limits

        #expect(limits.map(\.id) == ["session", "weekly"])
        #expect(limits[0].window == .session)
        #expect(limits[0].usedFraction == 0.45)
        #expect(limits[0].resetsAt == date("2026-01-15T15:00:00Z"))  // .987 s jitter rounds up
        #expect(limits[1].window == .weekly)
        #expect(limits[1].usedFraction == 0.08)
        #expect(limits[1].resetsAt == date("2026-01-17T09:00:00Z"))
    }

    @Test func fiveHourWindowIsASessionNotARollingWindow() throws {
        let session = try ClaudeUsageResponse.decode(Fixture.data("usage-pro")).limits.first
        #expect(session?.window == .session)
        #expect(session?.window != .rolling(length: .seconds(5 * 3600)))
    }

    @Test func mapsModelSpecificWeeklyLimitsAndIgnoresUnknownKeys() throws {
        let limits = try ClaudeUsageResponse.decode(Fixture.data("usage-max-model-limits")).limits

        #expect(limits.map(\.id) == ["session", "weekly", "weekly.opus", "weekly.sonnet"])
        #expect(limits[2].window == .weekly)
        #expect(limits[2].scope == "Opus")
        #expect(limits[2].usedFraction == 0.93)
        #expect(limits[3].scope == "Sonnet")
    }

    @Test func returnsOnlyWindowsThatArePresent() throws {
        let limits = try ClaudeUsageResponse.decode(Fixture.data("usage-partial")).limits
        #expect(limits.map(\.id) == ["weekly"])
    }

    @Test func keepsLimitsWithMissingFieldsAsUnknownNotZero() throws {
        let limits = try ClaudeUsageResponse.decode(Fixture.data("usage-missing-fields")).limits

        #expect(limits.map(\.id) == ["session", "weekly", "weekly.sonnet"])
        #expect(limits[0].usedFraction == nil)
        #expect(limits[0].resetsAt == nil)
        #expect(limits[1].usedFraction == 0.30)
        #expect(limits[1].resetsAt == nil)
        #expect(limits[2].resetsAt == nil)  // "not a date"
    }

    @Test(arguments: [
        "not json",
        "",
        "[]",
        "null",
        #"{"unexpected": true}"#,  // none of the known windows: the format changed
        #"{"five_hour": "45%"}"#,
        #"{"five_hour": {"utilization": "45"}}"#,
    ])
    func rejectsMalformedBodies(body: String) {
        #expect(throws: ProviderError.invalidResponse) {
            try ClaudeUsageResponse.decode(Data(body.utf8))
        }
    }

    @Test func acceptsAllWindowsNull() throws {
        let body = #"{"five_hour": null, "seven_day": null}"#
        #expect(try ClaudeUsageResponse.decode(Data(body.utf8)).limits.isEmpty)
    }

    @Test(arguments: [
        ("2026-10-22T23:09:59.987225+00:00", "2026-10-22T23:10:00Z"),
        ("2026-10-22T23:10:00.000431+00:00", "2026-10-22T23:10:00Z"),
        ("2026-10-22T23:10:00+00:00", "2026-10-22T23:10:00Z"),
        ("2026-10-22T20:10:00.5-03:00", "2026-10-22T23:10:01Z"),
        ("2026-10-22T23:10:00Z", "2026-10-22T23:10:00Z"),
    ])
    func parsesResetDates(input: String, expected: String) {
        #expect(ClaudeUsageResponse.Window.parseDate(input) == date(expected))
    }

    @Test func rejectsInvalidResetDates() {
        #expect(ClaudeUsageResponse.Window.parseDate("tomorrow") == nil)
        #expect(ClaudeUsageResponse.Window.parseDate("") == nil)
    }
}
