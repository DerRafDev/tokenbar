import SwiftUI
import TokenBarCore

/// One limit: title, percentage, bar, and reset time.
struct LimitRow: View {
    let limit: UsageLimit
    let now: Date
    let formatter: UsageFormatter

    var body: some View {
        let hasReset = limit.hasReset(at: now)
        let reset = formatter.resetDescription(limit.resetsAt, now: now)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer()
                Text("\(formatter.percent(limit.usedFraction)) used", bundle: .module)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            UsageBar(fraction: limit.usedFraction, dimmed: hasReset)
            if let reset {
                Text(reset)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(
            [String(localized: "\(formatter.percent(limit.usedFraction)) used", bundle: .module), reset]
                .compactMap(\.self)
                .joined(separator: ", ")
        )
    }

    private var title: String {
        let base =
            switch limit.window {
            case .session: String(localized: "Current session", bundle: .module)
            case .rolling(let length):
                String(localized: "Rolling window (\(formatter.duration(length.timeInterval)))", bundle: .module)
            case .daily: String(localized: "Today", bundle: .module)
            case .weekly: String(localized: "Weekly", bundle: .module)
            case .monthly: String(localized: "Monthly", bundle: .module)
            }
        guard let scope = limit.scope else { return base }
        return "\(base) · \(scope)"
    }
}
