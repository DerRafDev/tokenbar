import TokenBarCore

/// Builds the compact per-provider text shown in the menu bar, such as "S 17% | W 79%".
///
/// Every number carries a letter so its meaning is clear at a glance:
/// S = session, D = daily, W = weekly, M = monthly. Only limits that apply to all models
/// are shown; model-specific limits stay in the popover.
public enum MenuBarSummary {
    public static func text(for snapshot: UsageSnapshot, formatter: UsageFormatter) -> String? {
        let parts = LimitWindow.allCases.compactMap { window -> String? in
            guard let limit = snapshot.limit(window) else { return nil }
            return "\(abbreviation(for: window)) \(formatter.percent(limit.usedFraction))"
        }
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }

    static func abbreviation(for window: LimitWindow) -> String {
        switch window {
        case .session: "S"
        case .daily: "D"
        case .weekly: "W"
        case .monthly: "M"
        }
    }
}
