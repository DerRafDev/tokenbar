import Foundation

/// Identifies one agent session, such as a Claude Code session. The same session ID from two
/// providers is two different sessions.
public struct AgentSessionKey: Hashable, Sendable {
    public let provider: ProviderID
    public let sessionID: String

    public init(provider: ProviderID, sessionID: String) {
        self.provider = provider
        self.sessionID = sessionID
    }
}

/// Why a session is waiting for the user.
public enum AgentWaitReason: Hashable, Sendable {
    /// The agent asked a structured question (Claude Code's `AskUserQuestion`).
    case answer
}

/// A normalized change in a session's waiting state, translated from a provider's own signals.
public struct AgentEvent: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// The session started waiting for the user.
        case waiting(AgentWaitReason)
        /// The session is no longer waiting: the user answered, or the session moved on.
        case resolved
        /// The session ended.
        case ended
    }

    public let key: AgentSessionKey
    public let kind: Kind
    /// Name of the tool the session runs in, such as "Claude Code". `nil` to use the provider's name.
    public let agentName: String?
    /// Folder name of the session's project, when known. Never a full path.
    public let project: String?
    /// Where the session is open. Read from "waiting" events.
    public let origin: AgentOrigin?
    public let date: Date

    public init(
        key: AgentSessionKey,
        kind: Kind,
        agentName: String? = nil,
        project: String?,
        origin: AgentOrigin? = nil,
        date: Date
    ) {
        self.key = key
        self.kind = kind
        self.agentName = agentName
        self.project = project
        self.origin = origin
        self.date = date
    }
}

/// A session that is waiting for the user right now.
public struct PendingAgentSession: Identifiable, Hashable, Sendable {
    public let key: AgentSessionKey
    public let reason: AgentWaitReason
    public let agentName: String?
    public let project: String?
    public let origin: AgentOrigin?
    /// When the session started waiting.
    public let since: Date

    public var id: AgentSessionKey { key }

    public init(
        key: AgentSessionKey,
        reason: AgentWaitReason,
        agentName: String?,
        project: String?,
        origin: AgentOrigin? = nil,
        since: Date
    ) {
        self.key = key
        self.reason = reason
        self.agentName = agentName
        self.project = project
        self.origin = origin
        self.since = since
    }
}

/// A source of agent events, such as Claude Code hooks.
public protocol AgentActivitySource: Sendable {
    var provider: ProviderID { get }

    /// Starts listening. Events arrive on the returned stream until ``stop()``.
    func start() throws -> AsyncStream<AgentEvent>
    func stop()
}
