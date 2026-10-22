import Foundation
import TokenBarCore

/// Builds the compact per-provider text shown in the menu bar, such as "S 17% | W 79%".
///
/// Every number carries a short label so its meaning is clear at a glance:
/// S = session, D = daily, W = weekly, M = monthly, and the length for rolling windows
/// ("5h 12%"). Limits keep the provider's order. Only limits that apply to all models are
/// shown; model-specific limits stay in the popover.
public enum MenuBarSummary {
    public static func text(for snapshot: UsageSnapshot, formatter: UsageFormatter) -> String? {
        let parts = snapshot.limits.filter { $0.scope == nil }.map { limit in
            "\(label(for: limit.window, formatter: formatter)) \(formatter.percent(limit.usedFraction))"
        }
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
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
