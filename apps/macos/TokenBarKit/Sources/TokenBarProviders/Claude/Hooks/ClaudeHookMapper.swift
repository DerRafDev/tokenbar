import Foundation
import TokenBarCore

/// Translates a Claude Code hook payload into an ``AgentEvent``.
///
/// Only structured questions (`AskUserQuestion`) count as waiting. Approvals are left out: Claude
/// Code sends no event when the user approves (only when the command finishes) or denies, so
/// TokenBar cannot tell when the user has decided. See docs/agents.md.
///
/// Reads only the event name, session ID, tool name, and the project folder name. Everything else
/// in the payload, including the question and the tool input, is never decoded.
public enum ClaudeHookMapper {
    static let questionTool = "AskUserQuestion"

    struct Payload: Decodable {
        let sessionID: String?
        let hookEventName: String?
        let toolName: String?
        let cwd: String?

        enum CodingKeys: String, CodingKey {
            case sessionID = "session_id"
            case hookEventName = "hook_event_name"
            case toolName = "tool_name"
            case cwd
        }
    }

    /// - Parameters:
    ///   - headers: Request headers, lowercased. The hook adds where Claude Code runs (see
    ///     ``origin(from:process:)``).
    ///   - process: Looks up a running process, to confirm the hook's claim about its terminal.
    public static func event(
        from body: Data,
        headers: [String: String] = [:],
        date: Date,
        process: (Int32) -> ProcessSnapshot? = { _ in nil }
    ) -> AgentEvent? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: body),
            let sessionID = payload.sessionID, !sessionID.isEmpty,
            let name = payload.hookEventName,
            let kind = kind(event: name, tool: payload.toolName)
        else { return nil }
        let project = payload.cwd.map { URL(filePath: $0).lastPathComponent }.flatMap { $0.isEmpty ? nil : $0 }
        return AgentEvent(
            key: AgentSessionKey(provider: "claude", sessionID: sessionID),
            kind: kind,
            agentName: "Claude Code",
            project: project,
            origin: kind == .waiting(.answer) ? origin(from: headers, process: process) : nil,
            date: date
        )
    }

    /// Where the session runs, from headers the hook command fills in from its environment:
    /// `x-origin-app` (`$__CFBundleIdentifier`), `x-origin-pid` (`$PPID`, the Claude Code process)
    /// and `x-origin-tty` (that process's terminal).
    ///
    /// The terminal is trusted only when the process is running and the kernel reports the same
    /// TTY; the process start time is kept so a reused process ID never matches later. Values that
    /// do not look exactly like a bundle ID, a process ID, or a TTY name are dropped.
    static func origin(from headers: [String: String], process: (Int32) -> ProcessSnapshot?) -> AgentOrigin? {
        guard let app = headers["x-origin-app"], app.wholeMatch(of: /[A-Za-z0-9][A-Za-z0-9.\-]{0,154}/) != nil
        else { return nil }
        guard let tty = headers["x-origin-tty"], tty.wholeMatch(of: /ttys?[0-9]{1,4}/) != nil,
            let pid = headers["x-origin-pid"].flatMap(Int32.init), pid > 1,
            let snapshot = process(pid), snapshot.tty == tty
        else { return AgentOrigin(appBundleID: app) }
        return AgentOrigin(
            appBundleID: app,
            target: .terminalTab(tty: tty, process: AgentProcess(id: pid, startedAt: snapshot.startedAt))
        )
    }

    static func kind(event: String, tool: String?) -> AgentEvent.Kind? {
        switch event {
        case "PreToolUse":
            tool == questionTool ? .waiting(.answer) : nil
        case "PostToolUse", "PostToolUseFailure":
            tool == questionTool ? .resolved : nil
        // A new prompt or the end of a turn means the question is no longer open, including one
        // dismissed with Esc (which sends no event of its own).
        case "UserPromptSubmit", "Stop", "StopFailure":
            .resolved
        case "SessionEnd":
            .ended
        default:
            nil
        }
    }
}
