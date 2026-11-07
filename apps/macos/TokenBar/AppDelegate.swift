import AppKit
import OSLog
import TokenBarCore
import TokenBarProviders
import TokenBarUI

/// Owns long-lived objects and starts background refreshing at launch.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: AppSettings
    let store: UsageStore
    let launchAtLogin = LaunchAtLogin()
    let updater = SoftwareUpdater()
    /// Sessions waiting for the user. `nil` unless agent monitoring runs (Debug prototype).
    let agents: AgentActivityStore?
    /// Brings a waiting session's window to the front. `nil` with ``agents``.
    let navigator: AgentSessionNavigator?
    private let agentSource: (any AgentActivitySource)?
    private let logger = Logger(subsystem: Log.subsystem, category: "app")

    override init() {
        let registry = ProviderRegistry.make()
        // Type names and IDs only, so a console shows whether real or demo providers are running.
        let providers = registry.providers.map { "\(type(of: $0))(\($0.descriptor.id.rawValue))" }
        Logger(subsystem: Log.subsystem, category: "app")
            .notice("Registered providers: \(providers.joined(separator: ", "), privacy: .public)")
        settings = AppSettings(defaults: registry.defaults, initiallyEnabled: registry.initiallyEnabled)
        store = UsageStore(providers: registry.providers, enabledProviders: [])
        agentSource = registry.agentSource
        agents = registry.agentSource == nil ? nil : AgentActivityStore()
        navigator =
            registry.agentSource == nil ? nil : AgentSessionNavigator(environment: MacAgentNavigationEnvironment())
        super.init()
        store.follow(settings)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.startScheduledRefreshes()
        startAgentSource()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopScheduledRefreshes()
        agentSource?.stop()
    }

    private func startAgentSource() {
        guard let agentSource, let agents else { return }
        do {
            let events = try agentSource.start()
            Task {
                for await event in events { agents.apply(event) }
            }
        } catch {
            logger.error("Agent hooks could not start: \(String(describing: error), privacy: .public)")
        }
    }

    /// The scheduled refresh due during sleep runs at wake, usually before the network is back, so
    /// usage (and any reset that happened meanwhile) would stay outdated for a whole interval.
    /// Restarting the schedule a moment later refreshes once the connection has had time to return.
    @objc private func systemDidWake(_ notification: Notification) {
        Task {
            try? await Task.sleep(for: .seconds(10))
            store.startScheduledRefreshes()
        }
    }
}
