import SwiftUI
import TokenBarUI

/// Composition root. Builds dependencies and declares scenes; contains no logic.
@main
struct TokenBarApp: App {
    var body: some Scene {
        MenuBarExtra {
            UsagePopover()
        } label: {
            Image(systemName: "gauge.with.dots.needle.33percent")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
