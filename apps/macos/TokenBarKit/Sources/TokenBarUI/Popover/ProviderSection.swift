import SwiftUI
import TokenBarCore

/// One provider in the popover.
///
/// Collapsed, it is a compact overview: name, plan, the current session, and one line with every
/// limit ("Session 15% · Week 12%"). Expanded, it adds a bar and reset time per limit. Limits come
/// from the snapshot as a list, so providers with other windows (daily, monthly, rolling) need
/// nothing special here.
struct ProviderSection: View {
    let descriptor: ProviderDescriptor
    let state: ProviderState
    let policy: RefreshPolicy
    let now: Date
    let formatter: UsageFormatter
    let isExpanded: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    /// Leading inset that lines content up with the provider name.
    private static let contentInset = ProviderIcon.slotWidth + Spacing.small

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 3) {
                    header
                    if !isExpanded {
                        summaryLine
                            .padding(.leading, Self.contentInset)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(
                isExpanded
                    ? Text("Hides details", bundle: .module)
                    : Text("Shows details", bundle: .module)
            )

            if isExpanded {
                details
                    .padding(.leading, Self.contentInset)
                    .padding(.top, Spacing.medium)
                    .padding(.bottom, Spacing.tight)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.primary.opacity(isExpanded ? 0.05 : isHovered ? 0.035 : 0))
        )
        .onHover { isHovered = $0 }
    }

    private var header: some View {
        HStack(spacing: Spacing.small) {
            ProviderIcon(descriptor: descriptor, size: 18)
                .font(.title3)
            Text(descriptor.displayName)
                .font(.body.weight(.semibold))
                .lineLimit(1)
            if let plan = state.snapshot?.plan {
                Badge(text: plan)
            }
            if descriptor.isDemo {
                Badge(text: String(localized: "Demo", bundle: .module), tint: .orange)
            }
            Spacer(minLength: Spacing.small)
            headline
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
    }

    /// The provider's headline: its current session (see ``UsageSnapshot/headlineLimit``).
    @ViewBuilder
    private var headline: some View {
        if let limit = state.snapshot?.headlineLimit {
            let level = level(of: limit)
            Text(formatter.percent(limit.usedFraction))
                .font(.body.weight(level == .normal ? .regular : .semibold))
                .monospacedDigit()
                .foregroundStyle(level.color ?? .primary)
        } else if state.snapshot == nil, state.error == nil {
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel(Text("Loading…", bundle: .module))
        }
    }

    /// One line under the name while collapsed: every limit, or why there are none.
    @ViewBuilder
    private var summaryLine: some View {
        Group {
            if let snapshot = state.snapshot {
                let limits = snapshot.primaryLimits
                if limits.isEmpty {
                    Text("No usage limits reported.", bundle: .module)
                } else {
                    (state.isStale(at: now, policy: policy) ? staleMark : Text(verbatim: ""))
                        + limitsText(limits)
                }
            } else if let error = state.error {
                (Text(Image(systemName: Self.symbol(for: error))) + Text(verbatim: " ") + Text(message(for: error)))
                    .lineLimit(2)
            } else {
                Text("Loading…", bundle: .module)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private var staleMark: Text {
        Text(Image(systemName: "clock.badge.exclamationmark")).foregroundStyle(.orange) + Text(verbatim: " ")
    }

    /// "Session 15% · Week 12%". Values only stand out once they get close to the limit.
    private func limitsText(_ limits: [UsageLimit]) -> Text {
        limits.enumerated().reduce(Text(verbatim: "")) { text, element in
            let (index, limit) = element
            var value = Text(formatter.percent(limit.usedFraction)).monospacedDigit()
            if let color = level(of: limit).color {
                value = value.fontWeight(.semibold).foregroundStyle(color)
            }
            return text + Text(verbatim: index == 0 ? "" : "  ·  ")
                + Text(verbatim: "\(formatter.shortTitle(for: limit)) ") + value
        }
    }

    /// A limit whose reset has passed shows outdated usage, so it never raises the alarm.
    private func level(of limit: UsageLimit) -> UsageLevel {
        limit.hasReset(at: now) ? .normal : UsageLevel(limit.usedFraction)
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if let snapshot = state.snapshot {
                if state.isStale(at: now, policy: policy) {
                    StatusNote(
                        text: staleMessage(fetchedAt: snapshot.fetchedAt), symbolName: "clock.badge.exclamationmark")
                }
                if snapshot.limits.isEmpty {
                    Text("No usage limits reported.", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(snapshot.limits) { limit in
                    LimitRow(limit: limit, now: now, formatter: formatter)
                }
            } else if let error = state.error {
                StatusNote(text: message(for: error), symbolName: Self.symbol(for: error), prominent: true)
            } else {
                loadingPlaceholder
            }
        }
    }

    /// Two redacted rows in the shape of real limits, so the details do not jump when data arrives.
    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ForEach(Self.placeholderLimits) { limit in
                LimitRow(limit: limit, now: now, formatter: formatter)
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading…", bundle: .module))
    }

    private static let placeholderLimits = [
        UsageLimit(id: "session", window: .session, usedFraction: nil, resetsAt: nil),
        UsageLimit(id: "weekly", window: .weekly, usedFraction: nil, resetsAt: nil),
    ]

    private func staleMessage(fetchedAt: Date) -> String {
        let updated = formatter.updatedDescription(fetchedAt, now: now)
        guard let error = state.error else { return updated }
        return "\(updated). \(message(for: error))"
    }

    /// Like ``message(for:)``, plus when TokenBar may ask again after a rate limit.
    private func message(for error: ProviderError) -> String {
        if case .rateLimited = error, let retry = state.retryNotBefore, retry > now {
            return String(localized: "Too many requests. Trying again at \(formatter.time(retry)).", bundle: .module)
        }
        return Self.message(for: error)
    }

    static func message(for error: ProviderError) -> String {
        switch error {
        case .notConnected:
            String(localized: "Not connected. See Settings › Providers for what's needed.", bundle: .module)
        case .unauthorized:
            String(localized: "Sign-in expired. Sign in again to resume updates.", bundle: .module)
        case .accessDenied:
            String(localized: "Access was not allowed. Refresh to be asked again.", bundle: .module)
        case .rateLimited:
            String(localized: "Too many requests. Will retry later.", bundle: .module)
        case .offline:
            String(localized: "You're offline.", bundle: .module)
        case .timedOut:
            String(localized: "The service took too long to respond.", bundle: .module)
        case .invalidResponse:
            String(localized: "Unexpected response. TokenBar may need an update.", bundle: .module)
        case .server(let statusCode):
            String(localized: "The service returned an error (\(statusCode)).", bundle: .module)
        case .unknown:
            String(localized: "Something went wrong.", bundle: .module)
        }
    }

    static func symbol(for error: ProviderError) -> String {
        switch error {
        case .notConnected: "link"
        case .unauthorized: "person.crop.circle.badge.exclamationmark"
        case .accessDenied: "lock"
        case .rateLimited: "hourglass"
        case .offline: "wifi.slash"
        default: "exclamationmark.triangle"
        }
    }
}

/// The provider's logo, or its symbol when it has none, in a fixed-width slot so names line up.
struct ProviderIcon: View {
    let descriptor: ProviderDescriptor
    /// Edge length of a logo. Symbols follow the font instead.
    var size: CGFloat = 20

    /// Width every icon takes, whatever its shape.
    static let slotWidth: CGFloat = 24

    var body: some View {
        Group {
            if let logo = descriptor.logo, let image = LogoImage.load(logo) {
                Image(nsImage: image)
                    .renderingMode(logo.keepsColors ? .original : .template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: descriptor.symbolName)
                    .fontWeight(.medium)
            }
        }
        .frame(width: Self.slotWidth)
        .accessibilityHidden(true)
    }
}

/// Loads logos from this module's resources.
enum LogoImage {
    static func load(_ logo: ProviderLogo) -> NSImage? {
        Bundle.module.url(forResource: logo.resourceName, withExtension: "pdf", subdirectory: "Logos")
            .flatMap(NSImage.init(contentsOf:))
    }
}

/// A short secondary line about the provider's state, such as outdated data or a sign-in problem.
///
/// `prominent` is used when there is no usage to show: the message is then the main content.
struct StatusNote: View {
    let text: String
    let symbolName: String
    var prominent = false

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(prominent ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbolName)
                .foregroundStyle(prominent ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
        }
        .font(prominent ? .body : .callout)
    }
}

/// A small, quiet tag next to a provider name, such as its plan.
struct Badge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
