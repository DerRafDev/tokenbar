import SwiftUI
import TokenBarUI

/// Composition root. Declares scenes; dependencies live in `AppDelegate`.
@main
struct TokenBarApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            UsagePopover(store: appDelegate.store, agents: appDelegate.agents, navigator: appDelegate.navigator)
        } label: {
            MenuBarLabel(store: appDelegate.store, settings: appDelegate.settings, agents: appDelegate.agents)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                settings: appDelegate.settings,
                store: appDelegate.store,
                launchAtLogin: appDelegate.launchAtLogin
            )
        }
    }
}
