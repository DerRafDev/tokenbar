import AppKit
import OSLog
import TokenBarCore
import TokenBarUI

/// Owns long-lived objects and starts background refreshing at launch.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: AppSettings
    let store: UsageStore
    let launchAtLogin = LaunchAtLogin()

    override init() {
        let registry = ProviderRegistry.make()
        // Type names and IDs only, so a console shows whether real or demo providers are running.
        let providers = registry.providers.map { "\(type(of: $0))(\($0.descriptor.id.rawValue))" }
        Logger(subsystem: Log.subsystem, category: "app")
            .notice("Registered providers: \(providers.joined(separator: ", "), privacy: .public)")
        settings = AppSettings(defaults: registry.defaults, initiallyEnabled: registry.initiallyEnabled)
        store = UsageStore(providers: registry.providers, enabledProviders: [])
        super.init()
        store.follow(settings)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.startScheduledRefreshes()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopScheduledRefreshes()
    }
}
