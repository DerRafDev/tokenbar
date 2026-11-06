import SwiftUI
import TokenBarCore

/// Which page the popover shows.
enum PopoverTab: String, Hashable {
    case usage
    case agents

    /// The page shown when the popover opens: Agents while a session waits for the user, so one
    /// click goes from the menu bar alert to its details; Usage otherwise.
    static func initial(pendingCount: Int) -> PopoverTab {
        pendingCount > 0 ? .agents : .usage
    }
}

/// What the menu bar shows while agent sessions wait for an answer.
///
/// Named ("Claude · 2") when every waiting session belongs to one provider, so the menu bar says
/// who is asking. Compact ("2") when several providers are waiting or the user chose the Minimal
/// display. The amber dot in front is drawn by ``MenuBarLabel``.
enum AgentIndicator {
    struct Label: Equatable {
        /// Text after the dot, such as "Claude · 2" or "2".
        let text: String
        /// What VoiceOver reads, such as "Claude: 2 questions waiting for an answer".
        let spoken: String
    }

    /// `nil` when nothing is waiting, so the menu bar shows usage.
    static func label(for pending: [PendingAgentSession], names: [ProviderID: String], compact: Bool) -> Label? {
        guard !pending.isEmpty else { return nil }
        let count = pending.count
        let providers = Set(pending.map(\.key.provider))
        let name = providers.count == 1 ? providers.first.flatMap { names[$0] } : nil
        let questions =
            count == 1
            ? String(localized: "1 question waiting for an answer", bundle: .module)
            : String(localized: "\(count) questions waiting for an answer", bundle: .module)
        guard let name, !compact else {
            return Label(text: "\(count)", spoken: questions)
        }
        return Label(text: "\(name) · \(count)", spoken: "\(name): \(questions)")
    }
}

/// The Agents page: sessions waiting for the user, one row per session.
struct AgentsSection: View {
    let store: AgentActivityStore
    let navigator: AgentSessionNavigator?
    let descriptors: [ProviderDescriptor]
    let now: Date
    let formatter: UsageFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Waiting for you", bundle: .module)
                .font(.headline)
                .padding(.horizontal, Spacing.small)
                .padding(.top, Spacing.tight)
                .padding(.bottom, Spacing.small)
                .accessibilityAddTraits(.isHeader)
            let pending = store.pending
            if pending.isEmpty {
                emptyState
            }
            ForEach(Array(pending.enumerated()), id: \.element.id) { index, session in
                if index > 0 {
                    Divider().padding(.leading, PendingAgentRow.contentInset + Spacing.small)
                }
                PendingAgentRow(
                    session: session,
                    descriptor: descriptor(for: session.key.provider),
                    navigator: navigator,
                    now: now,
                    formatter: formatter,
                    onDismiss: { store.dismiss(session.key) }
                )
            }
        }
    }

    private func descriptor(for id: ProviderID) -> ProviderDescriptor {
        descriptors.first { $0.id == id } ?? ProviderDescriptor(id: id, displayName: id.rawValue)
    }

    private var emptyState: some View {
        Text("No agent is waiting for you.", bundle: .module)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.small)
    }
}

/// "Claude Code · TokenBar" over "Terminal · Waiting for an answer · 2m", with the session's
/// action and Dismiss on the trailing edge.
///
/// The button says what TokenBar can actually do (``AgentSessionNavigator``): "Go to Session" when
/// the exact tab is known and alive, "Open <App>" when only the app is, and nothing otherwise.
/// It never reopens the conversation or types into it; the user answers where the question is.
struct PendingAgentRow: View {
    let session: PendingAgentSession
    let descriptor: ProviderDescriptor
    let navigator: AgentSessionNavigator?
    let now: Date
    let formatter: UsageFormatter
    let onDismiss: () -> Void

    @State private var isHovered = false
    /// Set when "Go to Session" found the session closed, until the popover is drawn again.
    @State private var sessionClosed = false

    /// Leading inset that lines the text up with the title, past the icon.
    static let contentInset = ProviderIcon.slotWidth + Spacing.small

    var body: some View {
        // Actions sit under the text, so both lines keep the popover's full width.
        HStack(alignment: .top, spacing: Spacing.small) {
            ProviderIcon(descriptor: descriptor, size: 20)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                VStack(alignment: .leading, spacing: 2) {
                    title
                    Text(verbatim: detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                    if sessionClosed {
                        Text("This session is no longer open.", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
                .accessibilityElement(children: .combine)
                HStack(spacing: Spacing.small) {
                    if let action = navigator?.action(for: session.origin) {
                        actionButton(action)
                    }
                    Button(String(localized: "Dismiss", bundle: .module), action: onDismiss)
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .foregroundStyle(.secondary)
                        .help(
                            String(
                                localized: "Already answered or cancelled? Remove it from the list.", bundle: .module))
                }
                .padding(.top, Spacing.tight)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, Spacing.small + 2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.primary.opacity(isHovered ? 0.035 : 0))
        )
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func actionButton(_ action: AgentSessionAction) -> some View {
        switch action {
        case .goToSession:
            Button(String(localized: "Go to Session", bundle: .module), action: open)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(String(localized: "Shows the window and tab where the question is open.", bundle: .module))
        case .openApp(let name):
            Button(String(localized: "Open \(name)", bundle: .module), action: open)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(String(localized: "TokenBar can't find the exact window, so it opens the app.", bundle: .module))
        }
    }

    private func open() {
        guard let navigator else { return }
        sessionClosed = navigator.open(session.origin) == .sessionClosed
    }

    /// "Terminal · Waiting for an answer · now". The app is left out when it is unknown.
    private var detail: String {
        let parts = [navigator?.appName(for: session.origin), Self.reason(session.reason), elapsed]
        return parts.compactMap(\.self).joined(separator: " · ")
    }

    /// The agent's name stays whole; a long project name is shortened in the middle, so both its
    /// start and end stay recognizable.
    private var title: some View {
        HStack(spacing: 0) {
            Text(verbatim: session.agentName ?? descriptor.displayName)
                .layoutPriority(1)
            if let project = session.project {
                Text(verbatim: " · ")
                    .layoutPriority(1)
                Text(verbatim: project)
                    .truncationMode(.middle)
            }
        }
        .font(.body.weight(.semibold))
        .lineLimit(1)
    }

    /// "now" in the first minute, then "2m", "1h 5m".
    private var elapsed: String {
        let interval = now.timeIntervalSince(session.since)
        return interval < 60 ? String(localized: "now", bundle: .module) : formatter.countdown(interval)
    }

    static func reason(_ reason: AgentWaitReason) -> String {
        switch reason {
        case .answer: String(localized: "Waiting for an answer", bundle: .module)
        }
    }
}
