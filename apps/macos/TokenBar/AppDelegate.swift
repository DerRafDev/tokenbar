import AppKit
import TokenBarCore

/// Owns long-lived objects and starts background refreshing at launch.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = UsageStore(providers: ProviderRegistry.makeProviders())
    private var refreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        refreshTask = Task { [store] in await store.runScheduledRefreshes() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTask?.cancel()
    }
}
