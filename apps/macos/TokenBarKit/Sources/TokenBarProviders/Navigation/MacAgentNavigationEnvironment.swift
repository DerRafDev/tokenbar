import AppKit
import OSLog
import TokenBarCore

/// ``AgentNavigationEnvironment`` for macOS.
///
/// Exact targets are supported in Terminal.app only, where AppleScript can select a tab by its
/// TTY. Other apps (iTerm2, VS Code, tmux) get "Open <App>" until their own integration is
/// verified; see docs/agents.md.
///
/// Selecting a tab sends one Apple Event to Terminal, so macOS asks the user once to allow
/// TokenBar to control Terminal. Nothing is typed into the session.
@MainActor
public struct MacAgentNavigationEnvironment: AgentNavigationEnvironment {
    static let terminalBundleID = "com.apple.Terminal"
    private let logger = Logger(subsystem: Log.subsystem, category: "agents")

    public init() {}

    public func appName(bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacing(/\.app$/, with: "")
    }

    public func supportsExactTarget(_ target: AgentOrigin.Target, bundleID: String) -> Bool {
        switch target {
        case .terminalTab: bundleID == Self.terminalBundleID
        }
    }

    public func isRunning(_ process: AgentProcess, tty: String) -> Bool {
        guard let snapshot = SystemProcess.snapshot(of: process.id) else { return false }
        // Start times come from the same kernel field, so they match exactly for the same process.
        return abs(snapshot.startedAt.timeIntervalSince(process.startedAt)) < 0.001 && snapshot.tty == tty
    }

    public func showTerminalTab(tty: String, bundleID: String) -> Bool {
        // Never launches Terminal: a tab can only exist while it runs.
        guard bundleID == Self.terminalBundleID,
            !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty,
            tty.wholeMatch(of: /ttys?[0-9]{1,4}/) != nil
        else { return false }
        let source = """
            tell application id "\(Self.terminalBundleID)"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "/dev/\(tty)" then
                            -- Activate first: activation brings Terminal's last key window to the
                            -- front, which would cover the window chosen below.
                            activate
                            set index of w to 1
                            set selected of t to true
                            return true
                        end if
                    end repeat
                end repeat
                return false
            end tell
            """
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            logger.error("Could not select the Terminal tab (Apple Event error \(code, privacy: .public))")
            return false
        }
        return result?.booleanValue ?? false
    }

    public func activateApp(bundleID: String) -> Bool {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            return running.activate()
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return false }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        return true
    }
}
