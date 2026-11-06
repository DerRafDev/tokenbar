import Foundation
import Observation

/// Sessions waiting for the user, one entry per session.
///
/// Holds only what is waiting now. A resolved or ended session is removed, so a repeated or late
/// "resolved" event can never bring it back; only a new "waiting" event can. A repeated "waiting"
/// event keeps the original start time, so the counter never counts a session twice.
@MainActor
@Observable
public final class AgentActivityStore {
    public private(set) var waiting: [AgentSessionKey: PendingAgentSession] = [:]

    public init() {}

    /// Sessions waiting for the user, longest-waiting first.
    public var pending: [PendingAgentSession] {
        waiting.values.sorted { ($0.since, $0.key.sessionID) < ($1.since, $1.key.sessionID) }
    }

    /// Number of sessions that need the user, counted once per session.
    public var pendingCount: Int { waiting.count }

    public func apply(_ event: AgentEvent) {
        switch event.kind {
        case .waiting(let reason):
            guard waiting[event.key] == nil else { return }
            waiting[event.key] = PendingAgentSession(
                key: event.key, reason: reason, agentName: event.agentName, project: event.project,
                origin: event.origin,
                since: event.date)
        case .resolved, .ended:
            if waiting[event.key] != nil { waiting[event.key] = nil }
        }
    }

    /// Removes a session the user knows is no longer waiting, such as a question they dismissed
    /// with Esc. A later question from the same session shows up again.
    public func dismiss(_ key: AgentSessionKey) {
        waiting[key] = nil
    }

    public func removeAll(provider: ProviderID) {
        waiting = waiting.filter { $0.key.provider != provider }
    }
}
