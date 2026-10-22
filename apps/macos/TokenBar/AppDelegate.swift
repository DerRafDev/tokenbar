import AppKit
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
