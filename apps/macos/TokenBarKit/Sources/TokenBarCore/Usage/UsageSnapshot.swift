import Foundation

/// Normalized usage of one provider at one point in time.
public struct UsageSnapshot: Hashable, Sendable {
    public let provider: ProviderID
    /// Plan name as reported by the provider ("Pro", "Plus"), if known.
    public let plan: String?
    /// Limits in display order. May be empty if the provider reported none.
    public let limits: [UsageLimit]
    public let fetchedAt: Date

    public init(provider: ProviderID, plan: String?, limits: [UsageLimit], fetchedAt: Date) {
        self.provider = provider
        self.plan = plan
        self.limits = limits
        self.fetchedAt = fetchedAt
    }

    /// The first limit for `window`. Without `scope`, only limits that apply to every model match.
    public func limit(_ window: LimitWindow, scope: String? = nil) -> UsageLimit? {
        limits.first { $0.window == window && $0.scope == scope }
    }
}

/// One usage limit, such as "current session" or "weekly, Opus only".
public struct UsageLimit: Identifiable, Hashable, Sendable {
    /// Stable within a provider, for example `session`, `weekly`, `weekly.opus`.
    public let id: String
    public let window: LimitWindow
    /// Model or feature the limit applies to, or `nil` when it applies to everything.
    public let scope: String?
    /// Used share of the limit in `0...1`, or `nil` when the provider gives no percentage.
    /// This is different from zero usage.
    public let usedFraction: Double?
    /// When the limit resets, or `nil` when unknown.
    public let resetsAt: Date?

    public init(id: String, window: LimitWindow, scope: String? = nil, usedFraction: Double?, resetsAt: Date?) {
        self.id = id
        self.window = window
        self.scope = scope
        self.usedFraction = usedFraction.flatMap { $0.isFinite ? min(max($0, 0), 1) : nil }
        self.resetsAt = resetsAt
    }

    /// Convenience for providers that report usage as a percentage (`0...100`).
    public init(id: String, window: LimitWindow, scope: String? = nil, usedPercent: Double?, resetsAt: Date?) {
        self.init(id: id, window: window, scope: scope, usedFraction: usedPercent.map { $0 / 100 }, resetsAt: resetsAt)
    }

    /// True once the reset time has passed. The usage value is then outdated until the next refresh.
    public func hasReset(at now: Date) -> Bool {
        resetsAt.map { $0 <= now } ?? false
    }
}

/// The period a limit covers.
///
/// Add a case only when a provider actually reports a new kind of window.
public enum LimitWindow: String, Hashable, Sendable, CaseIterable {
    /// Short rolling window, such as Claude's and Codex's 5-hour session.
    case session
    case daily
    case weekly
    case monthly
}
