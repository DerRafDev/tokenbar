import SwiftUI
import TokenBarCore

/// Root of the native Settings window.
public struct SettingsView: View {
    let settings: AppSettings
    let store: UsageStore
    let launchAtLogin: LaunchAtLogin

    public init(settings: AppSettings, store: UsageStore, launchAtLogin: LaunchAtLogin) {
        self.settings = settings
        self.store = store
        self.launchAtLogin = launchAtLogin
    }

    public var body: some View {
        TabView {
            GeneralSettingsView(settings: settings, launchAtLogin: launchAtLogin)
                .tabItem {
                    Label(String(localized: "General", bundle: .module), systemImage: "gearshape")
                }
            ProvidersSettingsView(settings: settings, store: store)
                .tabItem {
                    Label(String(localized: "Providers", bundle: .module), systemImage: "square.stack.3d.up")
                }
        }
        .frame(width: 500)
    }
}

#if DEBUG
#Preview {
    let store = UsageStore(providers: [MockUsageProvider.claude(), MockUsageProvider.codex()])
    SettingsView(
        settings: AppSettings(defaults: UserDefaults(suiteName: "preview")!),
        store: store,
        launchAtLogin: LaunchAtLogin()
    )
}
#endif
