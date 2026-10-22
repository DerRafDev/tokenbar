import SwiftUI
import TokenBarUI

/// Composition root. Declares scenes; dependencies live in `AppDelegate`.
@main
struct TokenBarApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            UsagePopover(store: appDelegate.store)
        } label: {
            MenuBarLabel(store: appDelegate.store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
