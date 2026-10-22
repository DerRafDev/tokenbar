import Foundation
import TokenBarCore

/// The subset of `GET /api/oauth/usage` that TokenBar uses. Unknown keys are ignored.
///
/// Verified against a live response on 2026-10-22 (see docs/providers.md). Each window is
/// `{ "utilization": 0–100, "resets_at": ISO 8601 }`, or `null` when it does not apply to the plan.
struct ClaudeUsageResponse: Decodable {
    struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let sevenDayOpus: Window?
    let sevenDaySonnet: Window?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
    }

    /// Decodes a response body.
    ///
    /// Windows may be `null` or missing (partial data). The body is ``ProviderError/invalidResponse``
    /// when it is not a JSON object, a field has the wrong type, or none of the known windows is
    /// present at all, which means the format changed.
    static func decode(_ data: Data) throws -> ClaudeUsageResponse {
        let decoder = JSONDecoder()
        guard let keys = try? decoder.decode([String: JSONValue].self, from: data).keys,
            CodingKeys.allCases.contains(where: { keys.contains($0.rawValue) }),
            let response = try? decoder.decode(ClaudeUsageResponse.self, from: data)
        else { throw ProviderError.invalidResponse }
        return response
    }

    /// Accepts any JSON value; used only to read the top-level keys.
    private struct JSONValue: Decodable {
        init(from decoder: any Decoder) throws {}
    }

    /// Maps the response to limits, in display order.
    ///
    /// - `five_hour` is a **session**: the server's own `limits[].kind` is "session", Claude Code
    ///   calls it the "session limit", and `resets_at` stays fixed while usage grows. It is not a
    ///   rolling window.
    /// - `seven_day` is a fixed weekly window (the response reports when it started).
    /// - `seven_day_opus` / `seven_day_sonnet` are weekly limits for one model family.
    var limits: [UsageLimit] {
        [
            fiveHour.map { $0.limit(id: "session", window: .session) },
            sevenDay.map { $0.limit(id: "weekly", window: .weekly) },
            sevenDayOpus.map { $0.limit(id: "weekly.opus", window: .weekly, scope: "Opus") },
            sevenDaySonnet.map { $0.limit(id: "weekly.sonnet", window: .weekly, scope: "Sonnet") },
        ].compactMap(\.self)
    }
}

extension ClaudeUsageResponse.Window {
    func limit(id: String, window: LimitWindow, scope: String? = nil) -> UsageLimit {
        UsageLimit(
            id: id,
            window: window,
            scope: scope,
            usedPercent: utilization,
            resetsAt: resetsAt.flatMap(Self.parseDate)
        )
    }

    /// Parses `2026-10-22T23:09:59.987225+00:00`.
    ///
    /// Fractions are cut to milliseconds (older Foundation versions reject more digits), then the
    /// date is rounded to the second: the server reports boundaries with sub-second jitter, and
    /// `23:09:59.987` means a reset at 23:10.
    static func parseDate(_ string: String) -> Date? {
        var value = string
        if let dot = value.firstIndex(of: "."),
            let end = value[dot...].firstIndex(where: { !$0.isNumber && $0 != "." })
        {
            let fraction = value[value.index(after: dot)..<end].prefix(3)
            value.replaceSubrange(dot..<end, with: fraction.isEmpty ? "" : "." + fraction)
        }
        let date =
            (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value))
            ?? (try? Date.ISO8601FormatStyle().parse(value))
        return date.map { Date(timeIntervalSince1970: $0.timeIntervalSince1970.rounded()) }
    }
}
