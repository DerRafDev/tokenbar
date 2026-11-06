import Foundation
import TokenBarCore

/// Claude Code sessions waiting for an answer, reported by Claude Code hooks.
///
/// The hooks run `/usr/bin/curl` to post each payload to this listener and always exit 0, so
/// Claude Code shows no error and no delay while TokenBar is closed. This prototype does not
/// install hooks: they are configured by hand in a test folder (see docs/agents.md).
public final class ClaudeHookSource: AgentActivitySource, @unchecked Sendable {
    public static let defaultPort: UInt16 = 47811
    public static let path = "/hooks/claude"

    public let provider: ProviderID = "claude"
    private let server: LocalHookServer

    public init(port: UInt16 = ClaudeHookSource.defaultPort) {
        server = LocalHookServer(port: port, path: Self.path)
    }

    public func start() throws -> AsyncStream<AgentEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: AgentEvent.self)
        try server.start { headers, body in
            if let event = ClaudeHookMapper.event(
                from: body, headers: headers, date: Date(), process: SystemProcess.snapshot(of:))
            {
                continuation.yield(event)
            }
        }
        continuation.onTermination = { [server] _ in server.stop() }
        return stream
    }

    public func stop() {
        server.stop()
    }
}
