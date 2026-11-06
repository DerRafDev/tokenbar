import Foundation
import TokenBarCore
import TokenBarProviders

/// The single place that decides which providers the app runs.
enum ProviderRegistry {
    struct Configuration {
        let providers: [any UsageProvider]
        /// Where settings are stored. Demo mode keeps its own, so it never touches real preferences.
        let defaults: UserDefaults
        /// Enabled until the user changes the selection. Real providers always start disabled.
        let initiallyEnabled: Set<ProviderID>
        /// Reports agent sessions waiting for the user. Debug-only prototype, `nil` unless requested.
        var agentSource: (any AgentActivitySource)?
    }

    /// Debug builds listen for Claude Code hooks when launched with `TOKENBAR_AGENT_HOOKS=1`.
    /// Off in the shared scheme, absent from Release builds. See docs/agents.md.
    static let agentHooksKey = "TOKENBAR_AGENT_HOOKS"
    /// Optional port, so a second Debug build can listen next to one already running.
    static let agentHooksPortKey = "TOKENBAR_AGENT_HOOKS_PORT"

    static func agentSource(environment: [String: String]) -> (any AgentActivitySource)? {
        #if DEBUG
        if environment[agentHooksKey] == "1" {
            let port = environment[agentHooksPortKey].flatMap(UInt16.init) ?? ClaudeHookSource.defaultPort
            return ClaudeHookSource(port: port)
        }
        #endif
        return nil
    }

    static func make(environment: [String: String] = ProcessInfo.processInfo.environment) -> Configuration {
        #if DEBUG
        // Opt-in demo data for UI work: launch with `TOKENBAR_DEMO=1` (off in the shared scheme).
        if DemoMode.isRequested(in: environment),
            let defaults = UserDefaults(suiteName: "io.github.derrafdev.TokenBar.demo")
        {
            let providers = [MockUsageProvider.claude(), MockUsageProvider.codex()]
            return Configuration(
                providers: providers,
                defaults: defaults,
                initiallyEnabled: Set(providers.map(\.descriptor.id)),
                agentSource: agentSource(environment: environment)
            )
        }
        #endif
        // Every real provider starts disabled; the user enables it in Settings (see docs/roadmap.md).
        return Configuration(
            providers: [ClaudeProvider(), CodexProvider()],
            defaults: .standard,
            initiallyEnabled: [],
            agentSource: agentSource(environment: environment)
        )
    }
}
