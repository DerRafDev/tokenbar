import Foundation
import TokenBarCore

/// Builds the compact per-provider text shown in the menu bar, such as "S 17% | W 79%".
///
/// Every number carries a short label so its meaning is clear at a glance:
/// S = session, D = daily, W = weekly, M = monthly, and the length for rolling windows
/// ("5h 12%"). Limits keep the provider's order. Only limits that apply to all models are
/// shown; model-specific limits stay in the popover.
public enum MenuBarSummary {
    /// One labeled number, such as ("S", "17%").
    public struct Part: Hashable, Sendable {
        public let label: String
        public let value: String
    }

    public static func parts(for snapshot: UsageSnapshot, formatter: UsageFormatter) -> [Part] {
        menuBarLimits(of: snapshot).map { limit in
            Part(label: label(for: limit.window, formatter: formatter), value: formatter.percent(limit.usedFraction))
        }
    }

    public static func text(for snapshot: UsageSnapshot, formatter: UsageFormatter) -> String? {
        let parts = parts(for: snapshot, formatter: formatter).map { "\($0.label) \($0.value)" }
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }

    /// What VoiceOver reads for a provider, with every limit spelled out:
    /// "Claude: Current session, 17% used; Weekly, 79% used".
    public static func spokenText(for snapshot: UsageSnapshot, name: String, formatter: UsageFormatter) -> String {
        let limits = menuBarLimits(of: snapshot).map {
            "\(formatter.title(for: $0)), \(formatter.usedDescription($0.usedFraction))"
        }
        return "\(name): \(limits.joined(separator: "; "))"
    }

    private static func menuBarLimits(of snapshot: UsageSnapshot) -> [UsageLimit] {
        snapshot.limits.filter { $0.scope == nil }
    }

    static func label(for window: LimitWindow, formatter: UsageFormatter) -> String {
        switch window {
        case .session: "S"
        case .rolling(let length): formatter.countdown(length.timeInterval)
        case .daily: "D"
        case .weekly: "W"
        case .monthly: "M"
        }
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
