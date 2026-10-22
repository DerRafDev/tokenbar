import Foundation

/// How often usage is refreshed and when data counts as outdated.
public struct RefreshPolicy: Hashable, Sendable {
    /// Time between scheduled refreshes.
    public var interval: TimeInterval
    /// Upper bound for a single provider fetch.
    public var fetchTimeout: TimeInterval
    /// Wait after an HTTP 429 that did not include `Retry-After`.
    public var rateLimitBackoff: TimeInterval

    public init(interval: TimeInterval, fetchTimeout: TimeInterval = 30, rateLimitBackoff: TimeInterval = 15 * 60) {
        self.interval = interval
        self.fetchTimeout = fetchTimeout
        self.rateLimitBackoff = rateLimitBackoff
    }

    public static let `default` = RefreshPolicy(interval: 5 * 60)

    /// Intervals offered in Settings.
    public static let intervalChoices: [TimeInterval] = [2 * 60, 5 * 60, 10 * 60, 15 * 60]

    /// Data older than this is shown as outdated: two missed refreshes.
    public var staleAfter: TimeInterval { interval * 2 }
}

/// What caused a refresh. Determines whether recent data is reused.
public enum RefreshTrigger: Sendable {
    /// The periodic timer fired. Skips providers refreshed within the last half interval.
    case scheduled
    /// The popover opened. Refreshes only providers whose data is at least one interval old.
    case popoverOpened
    /// The user asked for it. Always refreshes, unless the provider is rate limiting us.
    case manual
}
