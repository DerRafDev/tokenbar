import SwiftUI
import TokenBarCore

/// How close a value is to its limit.
///
/// The UI stays quiet at ``normal`` and only draws attention once a limit gets close.
enum UsageLevel: Int, Comparable, Sendable {
    /// Below 70%.
    case normal
    /// 70% to 89%.
    case attention
    /// 90% and above.
    case critical

    /// Unknown usage counts as normal: there is nothing to warn about.
    init(_ fraction: Double?) {
        switch fraction ?? 0 {
        case ..<0.7: self = .normal
        case ..<0.9: self = .attention
        default: self = .critical
        }
    }

    static func < (lhs: UsageLevel, rhs: UsageLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Color for a value at this level, or `nil` to keep the surrounding style.
    var color: Color? {
        switch self {
        case .normal: nil
        case .attention: .orange
        case .critical: .red
        }
    }
}

extension UsageSnapshot {
    /// Limits that apply to every model, in provider order. When a provider only reports
    /// model-specific limits, those are used instead, so a provider is never shown empty.
    var primaryLimits: [UsageLimit] {
        let unscoped = limits.filter { $0.scope == nil }
        return unscoped.isEmpty ? limits : unscoped
    }

    /// The first primary limit that reports a percentage, or `nil` if none does.
    ///
    /// Providers list limits from the shortest window to the longest, so this is the current
    /// session for Claude and Codex: what matters while coding. Longer limits stay visible in
    /// the popover. This is the single number shown for the provider in the menu bar and the
    /// popover row.
    var headlineLimit: UsageLimit? {
        primaryLimits.first { $0.usedFraction != nil }
    }
}
