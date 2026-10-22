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
        VStack(alignment: .leading, spacing: 14) {
            header
            content
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: descriptor.symbolName)
                .font(.title2)
            Text(descriptor.displayName)
                .font(.title3.weight(.semibold))
            if let plan = state.snapshot?.plan {
                Badge(text: plan)
            }
            if descriptor.isDemo {
                Badge(text: String(localized: "Demo", bundle: .module), tint: .orange)
            }
            Spacer()
            if state.isRefreshing {
                ProgressView().controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = state.snapshot {
            if state.isStale(at: now, policy: policy) {
                Label(staleMessage(fetchedAt: snapshot.fetchedAt), systemImage: "clock.badge.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            if snapshot.limits.isEmpty {
                Text("No usage limits reported.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(snapshot.limits) { limit in
                LimitRow(limit: limit, now: now, formatter: formatter)
            }
        } else if let error = state.error {
            Label(Self.message(for: error), systemImage: Self.symbol(for: error))
                .foregroundStyle(.secondary)
        } else {
            Text("Loading…", bundle: .module)
                .foregroundStyle(.secondary)
        }
    }

    private func staleMessage(fetchedAt: Date) -> String {
        let updated = formatter.updatedDescription(fetchedAt, now: now)
        guard let error = state.error else { return updated }
        return "\(updated). \(Self.message(for: error))"
    }

    static func message(for error: ProviderError) -> String {
        switch error {
        case .notConnected:
            String(localized: "Not connected. Connect it in Settings.", bundle: .module)
        case .unauthorized:
            String(localized: "Sign-in expired. Sign in again to resume updates.", bundle: .module)
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
        case .offline: "wifi.slash"
        default: "exclamationmark.triangle"
        }
    }
}

struct Badge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
