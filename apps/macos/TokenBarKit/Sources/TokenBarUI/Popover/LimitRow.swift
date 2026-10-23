import SwiftUI
import TokenBarCore

/// One limit in a provider's details: name and percentage, a thin bar, and the reset time.
struct LimitRow: View {
    let limit: UsageLimit
    let now: Date
    let formatter: UsageFormatter

    var body: some View {
        let hasReset = limit.hasReset(at: now)
        let title = formatter.title(for: limit)
        let reset = formatter.resetDescription(limit.resetsAt, now: now)
        let level = hasReset ? .normal : UsageLevel(limit.usedFraction)

        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Text(formatter.percent(limit.usedFraction))
                    .font(.subheadline.weight(level == .normal ? .medium : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(level.color ?? .primary)
                    .layoutPriority(1)
            }
            UsageBar(fraction: limit.usedFraction, dimmed: hasReset)
            if let reset {
                Text(reset)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(
            [formatter.usedDescription(limit.usedFraction), reset].compactMap(\.self).joined(separator: ", ")
        )
    }
}
