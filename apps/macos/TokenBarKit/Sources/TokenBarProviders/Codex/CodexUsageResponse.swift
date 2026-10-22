import Foundation
import TokenBarCore

/// The subset of `GET /backend-api/wham/usage` that TokenBar uses. Unknown keys are ignored.
///
/// Verified against live responses on 2026-10-22 (see docs/providers.md). The response also
/// contains the account's email and IDs; they are deliberately not declared here, so they are
/// never decoded.
struct CodexUsageResponse: Decodable {
    struct Window: Decodable {
        /// 0–100. The server sends integers; decoded as `Double` to accept either.
        let usedPercent: Double?
        let limitWindowSeconds: Int?
        let resetAfterSeconds: Double?
        /// Unix seconds.
        let resetAt: Double?
    }

    struct RateLimit: Decodable {
        let primaryWindow: Window?
        let secondaryWindow: Window?

        /// Windows in the response. Their position (primary/secondary) says nothing about their length.
        var windows: [Window] { [primaryWindow, secondaryWindow].compactMap(\.self) }
    }

    /// A separate quota for one model or feature, such as a model with its own limits.
    struct AdditionalRateLimit: Decodable {
        /// Display name, for example the model name.
        let limitName: String?
        /// Stable identifier of the metered feature.
        let meteredFeature: String?
        let rateLimit: RateLimit?
    }

    let planType: String?
    let rateLimit: RateLimit?
    let additionalRateLimits: [AdditionalRateLimit]?

    /// Decodes a response body.
    ///
    /// `rate_limit` and its windows may be `null` (partial data). The body is
    /// ``ProviderError/invalidResponse`` when it is not a JSON object, a field has the wrong type,
    /// or the `rate_limit` key is missing entirely, which means the format changed.
    static func decode(_ data: Data) throws -> CodexUsageResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let keys = try? JSONDecoder().decode([String: JSONValue].self, from: data).keys,
            keys.contains("rate_limit"),
            let response = try? decoder.decode(CodexUsageResponse.self, from: data)
        else { throw ProviderError.invalidResponse }
        return response
    }

    /// Accepts any JSON value; used only to read the top-level keys.
    private struct JSONValue: Decodable {
        init(from decoder: any Decoder) throws {}
    }

    /// Maps the response to limits: the plan's own limits first, then per-model limits, each
    /// ordered from the shortest window to the longest.
    ///
    /// Windows with a length TokenBar cannot name are left out rather than mislabeled.
    /// `fetchedAt` is only used when the server sends a relative reset without an absolute one.
    func limits(fetchedAt: Date) -> [UsageLimit] {
        var limits = rateLimit.map { $0.limits(scope: nil, idSuffix: nil, fetchedAt: fetchedAt) } ?? []
        for additional in additionalRateLimits ?? [] {
            guard let rateLimit = additional.rateLimit,
                let suffix = additional.meteredFeature ?? additional.limitName
            else { continue }
            let scope = additional.limitName ?? additional.meteredFeature
            limits += rateLimit.limits(scope: scope, idSuffix: suffix, fetchedAt: fetchedAt)
        }
        // A provider must not report two limits with the same ID; keep the first.
        var seen = Set<String>()
        return limits.filter { seen.insert($0.id).inserted }
    }
}

extension CodexUsageResponse.RateLimit {
    func limits(scope: String?, idSuffix: String?, fetchedAt: Date) -> [UsageLimit] {
        windows
            .compactMap { window -> (Int, UsageLimit)? in
                guard let seconds = window.limitWindowSeconds,
                    let kind = CodexUsageResponse.Window.kind(seconds: seconds)
                else { return nil }
                let id = [kind.id, idSuffix].compactMap(\.self).joined(separator: ".")
                return (seconds, window.limit(id: id, window: kind.window, scope: scope, fetchedAt: fetchedAt))
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)
    }
}

extension CodexUsageResponse.Window {
    /// Names a window by its length.
    ///
    /// The 5-hour window is a **session**, not a rolling window: it starts with the first request
    /// after the previous window ended and then resets at a fixed time. Evidence: `reset_at` stays
    /// fixed while usage grows for hours, and while no window is active the server reports 0% with
    /// a reset that moves with the clock (now + 5 hours). The weekly window behaves the same way.
    static func kind(seconds: Int) -> (id: String, window: LimitWindow)? {
        switch seconds {
        case 5 * 3600: ("session", .session)
        case 86_400: ("daily", .daily)
        case 7 * 86_400: ("weekly", .weekly)
        case 30 * 86_400: ("monthly", .monthly)
        default: nil
        }
    }

    func limit(id: String, window: LimitWindow, scope: String?, fetchedAt: Date) -> UsageLimit {
        UsageLimit(
            id: id,
            window: window,
            scope: scope,
            usedPercent: usedPercent,
            resetsAt: resetDate(fetchedAt: fetchedAt)
        )
    }

    /// When the window resets, or `nil` while it has not started.
    ///
    /// A window that has not started reports 0% and a full window left. Its reset is only "now +
    /// length" and moves on every request, so it is not shown as a reset time.
    func resetDate(fetchedAt: Date) -> Date? {
        if let length = limitWindowSeconds, let remaining = resetAfterSeconds, usedPercent == 0,
            remaining >= Double(length) - Self.idleTolerance
        {
            return nil
        }
        if let resetAt { return Date(timeIntervalSince1970: resetAt) }
        return resetAfterSeconds.map { fetchedAt.addingTimeInterval($0) }
    }

    /// Slack for the server's clock and rounding when detecting a window that has not started.
    static let idleTolerance: TimeInterval = 60
}
