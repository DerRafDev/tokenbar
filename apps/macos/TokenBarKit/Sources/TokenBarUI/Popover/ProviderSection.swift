import SwiftUI
import TokenBarCore

/// Header plus limits (or a status message) for one provider.
struct ProviderSection: View {
    let descriptor: ProviderDescriptor
    let state: ProviderState
    let policy: RefreshPolicy
    let now: Date
    let formatter: UsageFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            header
            content
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.small) {
            ProviderIcon(symbolName: descriptor.symbolName)
                .font(.title2)
            Text(descriptor.displayName)
                .font(.title3.weight(.semibold))
            if let plan = state.snapshot?.plan {
                Badge(text: plan)
            }
            if descriptor.isDemo {
                Badge(text: String(localized: "Demo", bundle: .module), tint: .orange)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = state.snapshot {
            if state.isStale(at: now, policy: policy) {
                StatusNote(text: staleMessage(fetchedAt: snapshot.fetchedAt), symbolName: "clock.badge.exclamationmark")
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

    /// Two redacted rows in the shape of real limits, so the popover does not jump when data arrives.
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

/// The provider's symbol in a fixed-width slot, so names line up across providers.
struct ProviderIcon: View {
    let symbolName: String

    var body: some View {
        Image(systemName: symbolName)
            .fontWeight(.medium)
            .frame(width: 24)
            .accessibilityHidden(true)
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
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
