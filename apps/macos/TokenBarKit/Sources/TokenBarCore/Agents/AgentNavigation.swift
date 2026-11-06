import Foundation

/// Where an agent session is open: the app that runs it and, when it can be told apart from other
/// sessions, the exact place inside that app.
///
/// Separate from ``AgentSessionKey``: the session ID names the conversation, the origin names the
/// window it lives in, which depends on the user's environment.
public struct AgentOrigin: Hashable, Sendable {
    /// Bundle identifier of the app the session runs in, such as `com.apple.Terminal`.
    public let appBundleID: String?
    public let target: Target?

    public enum Target: Hashable, Sendable {
        /// A terminal tab, found by its TTY. The TTY of a closed tab is soon reused by a new one,
        /// so the agent process that owns it is part of the target and checked before every use.
        case terminalTab(tty: String, process: AgentProcess)
    }

    public init(appBundleID: String?, target: Target? = nil) {
        self.appBundleID = appBundleID
        self.target = target
    }
}

/// A process, identified by its ID and start time, so a reused process ID never matches.
public struct AgentProcess: Hashable, Sendable {
    public let id: Int32
    public let startedAt: Date

    public init(id: Int32, startedAt: Date) {
        self.id = id
        self.startedAt = startedAt
    }
}

/// What the popover offers for a waiting session.
public enum AgentSessionAction: Hashable, Sendable {
    /// Bring the exact window and tab with the question to the front.
    case goToSession
    /// Only the app is known: bring it to the front.
    case openApp(name: String)
}

public enum AgentNavigationResult: Hashable, Sendable {
    case openedSession
    case openedApp
    /// The session's tab or process is gone. Nothing was brought to the front.
    case sessionClosed
    case failed
}

/// The system calls navigation needs. Implemented with AppKit and Apple Events in the app,
/// and by a fake in tests.
@MainActor
public protocol AgentNavigationEnvironment {
    /// Display name of an installed app, such as "Terminal". `nil` when it is not installed.
    func appName(bundleID: String) -> String?
    /// Whether the app can bring one of its own sessions to the front for this kind of target.
    func supportsExactTarget(_ target: AgentOrigin.Target, bundleID: String) -> Bool
    /// Whether the process is still running, is the same process (start time), and owns the TTY.
    func isRunning(_ process: AgentProcess, tty: String) -> Bool
    /// Selects the tab that owns `tty` and brings its window to the front. `false` when the app
    /// has no such tab.
    func showTerminalTab(tty: String, bundleID: String) -> Bool
    func activateApp(bundleID: String) -> Bool
}

/// Decides what a waiting session's button does, and does it.
///
/// "Go to session" is offered only when the exact target is known and still alive, and is checked
/// again on click: a closed tab never leads to a different one that happens to reuse its TTY.
@MainActor
public final class AgentSessionNavigator {
    private let environment: any AgentNavigationEnvironment

    public init(environment: any AgentNavigationEnvironment) {
        self.environment = environment
    }

    /// Name of the app the session runs in, for display.
    public func appName(for origin: AgentOrigin?) -> String? {
        origin?.appBundleID.flatMap(environment.appName(bundleID:))
    }

    public func action(for origin: AgentOrigin?) -> AgentSessionAction? {
        guard let origin, let bundleID = origin.appBundleID, let name = environment.appName(bundleID: bundleID)
        else { return nil }
        if let target = origin.target, isAlive(target, bundleID: bundleID) {
            return .goToSession
        }
        return .openApp(name: name)
    }

    public func open(_ origin: AgentOrigin?) -> AgentNavigationResult {
        guard let origin, let bundleID = origin.appBundleID, environment.appName(bundleID: bundleID) != nil
        else { return .failed }
        if let target = origin.target {
            // Checked again: the session may have closed since the popover was drawn.
            guard isAlive(target, bundleID: bundleID) else { return .sessionClosed }
            switch target {
            case .terminalTab(let tty, _):
                if environment.showTerminalTab(tty: tty, bundleID: bundleID) { return .openedSession }
            }
            // The process lives but has no tab of its own (for example inside tmux): the app is
            // the closest place that is certain.
        }
        return environment.activateApp(bundleID: bundleID) ? .openedApp : .failed
    }

    private func isAlive(_ target: AgentOrigin.Target, bundleID: String) -> Bool {
        guard environment.supportsExactTarget(target, bundleID: bundleID) else { return false }
        switch target {
        case .terminalTab(let tty, let process):
            return environment.isRunning(process, tty: tty)
        }
    }
}
