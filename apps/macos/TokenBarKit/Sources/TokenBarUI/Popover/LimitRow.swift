import SwiftUI
import TokenBarCore

/// One limit: title and percentage, bar, and reset time.
struct LimitRow: View {
    let limit: UsageLimit
    let now: Date
    let formatter: UsageFormatter

    var body: some View {
        let hasReset = limit.hasReset(at: now)
        let title = formatter.title(for: limit)
        let reset = formatter.resetDescription(limit.resetsAt, now: now)

        VStack(alignment: .leading, spacing: Spacing.tight) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                // The number is what people scan for; "used" only explains it.
                Text(
                    "\(Text(formatter.percent(limit.usedFraction)).fontWeight(.semibold).foregroundStyle(.primary)) used",
                    bundle: .module
                )
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .layoutPriority(1)
            }
            UsageBar(fraction: limit.usedFraction, dimmed: hasReset)
            if let reset {
                Text(reset)
                    .font(.callout)
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
