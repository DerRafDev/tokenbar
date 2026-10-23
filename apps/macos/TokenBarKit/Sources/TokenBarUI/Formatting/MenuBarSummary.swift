import Foundation
import TokenBarCore

/// Builds what the menu bar shows for each provider.
///
/// The menu bar answers one question at a glance: which provider is closest to its limit?
/// - ``MenuBarDisplayMode/providers``: each provider's highest usage ("15%").
/// - ``MenuBarDisplayMode/minimal``: only the provider with the highest usage.
/// - ``MenuBarDisplayMode/detailed``: each provider's first two limits ("15/12"), in provider order.
///
/// Only limits that apply to all models count; model-specific limits stay in the popover.
public enum MenuBarSummary {
    /// Values shown after a provider's icon, joined by "/" when there are several.
    static func values(
        for snapshot: UsageSnapshot,
        mode: MenuBarDisplayMode,
        formatter: UsageFormatter
    ) -> [String] {
        switch mode {
        case .providers, .minimal:
            guard let headline = snapshot.headlineLimit else {
                return snapshot.primaryLimits.isEmpty ? [] : [formatter.percent(nil)]
            }
            return [formatter.percent(headline.usedFraction)]
        case .detailed:
            let limits = snapshot.primaryLimits.prefix(2)
            // A single value keeps its unit; "15" alone would read as a count.
            guard limits.count > 1 else { return limits.map { formatter.percent($0.usedFraction) } }
            return limits.map { formatter.percentNumber($0.usedFraction) }
        }
    }

    /// Plain text of ``values(for:mode:formatter:)``, such as "15%" or "15/12".
    static func text(for snapshot: UsageSnapshot, mode: MenuBarDisplayMode, formatter: UsageFormatter) -> String? {
        let values = values(for: snapshot, mode: mode, formatter: formatter)
        return values.isEmpty ? nil : values.joined(separator: "/")
    }

    /// The most severe level among the limits a mode shows.
    static func level(of snapshot: UsageSnapshot, mode: MenuBarDisplayMode) -> UsageLevel {
        switch mode {
        case .providers, .minimal: UsageLevel(snapshot.headlineLimit?.usedFraction)
        case .detailed: snapshot.primaryLimits.prefix(2).map { UsageLevel($0.usedFraction) }.max() ?? .normal
        }
    }

    /// Modes to try, most detailed first, when the preferred one does not fit the menu bar.
    /// ``MenuBarDisplayMode/minimal`` always fits, so it is always last.
    static func fallbacks(for mode: MenuBarDisplayMode) -> [MenuBarDisplayMode] {
        switch mode {
        case .detailed: [.detailed, .providers, .minimal]
        case .providers: [.providers, .minimal]
        case .minimal: [.minimal]
        }
    }

    /// What VoiceOver reads for a provider, with every limit spelled out:
    /// "Claude: Current session, 17% used; Weekly, 79% used".
    public static func spokenText(for snapshot: UsageSnapshot, name: String, formatter: UsageFormatter) -> String {
        let limits = snapshot.primaryLimits.map {
            "\(formatter.title(for: $0)), \(formatter.usedDescription($0.usedFraction))"
        }
        return "\(name): \(limits.joined(separator: "; "))"
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
