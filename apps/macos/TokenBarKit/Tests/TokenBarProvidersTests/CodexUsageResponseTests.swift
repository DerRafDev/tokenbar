import Foundation
import Testing
import TokenBarCore

@testable import TokenBarProviders

struct CodexUsageResponseTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func limits(_ fixture: String) throws -> [UsageLimit] {
        try CodexUsageResponse.decode(Fixture.data(fixture, in: "Codex")).limits(fetchedAt: now)
    }

    @Test func mapsLivePlusResponse() throws {
        let response = try CodexUsageResponse.decode(Fixture.data("usage-plus", in: "Codex"))
        let limits = response.limits(fetchedAt: now)

        #expect(response.planType == "plus")
        #expect(limits.map(\.id) == ["session", "weekly"])
        #expect(limits[0].window == .session)
        #expect(limits[0].scope == nil)
        #expect(limits[0].usedFraction == 0.12)
        #expect(limits[0].resetsAt == Date(timeIntervalSince1970: 1_800_008_520))
        #expect(limits[1].window == .weekly)
        #expect(limits[1].usedFraction == 0.42)
        #expect(limits[1].resetsAt == Date(timeIntervalSince1970: 1_800_374_400))
    }

    @Test func fiveHourWindowIsASessionNotARollingWindow() throws {
        let fiveHours = try limits("usage-plus").first
        #expect(fiveHours?.window == .session)
        #expect(fiveHours?.window != .rolling(length: .seconds(5 * 3600)))
    }

    @Test func identifiesWindowsByLengthNotPosition() throws {
        // Weekly is the primary window here; the order of the result still follows the length.
        let limits = try limits("usage-pro-model-limits").filter { $0.scope == nil }
        #expect(limits.map(\.id) == ["session", "weekly"])
        #expect(limits[0].usedFraction == 0.05)
        #expect(limits[1].usedFraction == 0)
    }

    @Test func mapsModelSpecificLimitsAndIgnoresUnknownKeys() throws {
        let limits = try limits("usage-pro-model-limits")

        #expect(limits.map(\.id) == ["session", "weekly", "session.codex_bengalfox", "weekly.codex_bengalfox"])
        #expect(limits[2].window == .session)
        #expect(limits[2].scope == "GPT-5.3-Codex-Spark")
        #expect(limits[2].usedFraction == 0.31)
        #expect(limits[3].window == .weekly)
        #expect(limits[3].scope == "GPT-5.3-Codex-Spark")
        #expect(limits[3].usedFraction == 1)
        #expect(limits[3].resetsAt == Date(timeIntervalSince1970: 1_800_172_800))
    }

    @Test func hidesTheMovingResetOfAWindowThatHasNotStarted() throws {
        let limits = try limits("usage-idle")

        #expect(limits.map(\.id) == ["session", "weekly"])
        #expect(limits[0].usedFraction == 0)
        #expect(limits[0].resetsAt == nil)
        // 0% in a window that has started still has a real reset.
        #expect(limits[1].usedFraction == 0)
        #expect(limits[1].resetsAt == Date(timeIntervalSince1970: 1_800_512_000))
    }

    @Test func showsTheResetOnceAWindowHasUsage() {
        let window = CodexUsageResponse.Window(
            usedPercent: 1,
            limitWindowSeconds: 18_000,
            resetAfterSeconds: 17_990,
            resetAt: 1_800_017_990
        )
        #expect(window.resetDate(fetchedAt: now) == Date(timeIntervalSince1970: 1_800_017_990))
    }

    @Test func returnsOnlyWindowsThatArePresent() throws {
        #expect(try limits("usage-partial").map(\.id) == ["weekly"])
    }

    @Test func keepsMissingValuesUnknownAndSkipsWindowsItCannotName() throws {
        let limits = try limits("usage-missing-fields")

        // The 1-hour window is left out rather than mislabeled.
        #expect(limits.map(\.id) == ["session"])
        #expect(limits[0].usedFraction == nil)
        // No absolute reset: computed from the relative one.
        #expect(limits[0].resetsAt == now.addingTimeInterval(600))
    }

    @Test func acceptsNullRateLimit() throws {
        let body = #"{"plan_type": "free", "rate_limit": null}"#
        #expect(try CodexUsageResponse.decode(Data(body.utf8)).limits(fetchedAt: now).isEmpty)
    }

    @Test func keepsTheFirstOfTwoWindowsWithTheSameLength() throws {
        let body = """
            {"rate_limit": {
              "primary_window": {"used_percent": 10, "limit_window_seconds": 18000},
              "secondary_window": {"used_percent": 90, "limit_window_seconds": 18000}
            }}
            """
        let limits = try CodexUsageResponse.decode(Data(body.utf8)).limits(fetchedAt: now)
        #expect(limits.map(\.usedFraction) == [0.1])
    }

    @Test func doesNotDecodeAccountIdentifiers() throws {
        let body = #"{"email": "someone@example.com", "user_id": "u", "account_id": "a", "rate_limit": null}"#
        let response = try CodexUsageResponse.decode(Data(body.utf8))
        #expect(!String(describing: response).contains("example.com"))
    }

    @Test(arguments: [
        "not json",
        "",
        "[]",
        "null",
        #"{"plan_type": "plus"}"#,  // no rate_limit key: the format changed
        #"{"rate_limit": "12%"}"#,
        #"{"rate_limit": {"primary_window": {"used_percent": "12"}}}"#,
        #"{"rate_limit": null, "additional_rate_limits": {}}"#,
    ])
    func rejectsMalformedBodies(body: String) {
        #expect(throws: ProviderError.invalidResponse) {
            try CodexUsageResponse.decode(Data(body.utf8))
        }
    }

    @Test(arguments: [
        (18_000, LimitWindow.session),
        (86_400, .daily),
        (604_800, .weekly),
        (2_592_000, .monthly),
    ])
    func namesKnownWindowLengths(seconds: Int, expected: LimitWindow) {
        #expect(CodexUsageResponse.Window.kind(seconds: seconds)?.window == expected)
    }

    @Test(arguments: [0, 3_600, 17_999, 1_209_600])
    func doesNotNameOtherLengths(seconds: Int) {
        #expect(CodexUsageResponse.Window.kind(seconds: seconds) == nil)
    }
}
