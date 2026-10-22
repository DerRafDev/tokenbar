import AppKit
import TokenBarCore

/// Owns long-lived objects and starts background refreshing at launch.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = UsageStore(providers: ProviderRegistry.makeProviders())

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.startScheduledRefreshes()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopScheduledRefreshes()
    }
}
