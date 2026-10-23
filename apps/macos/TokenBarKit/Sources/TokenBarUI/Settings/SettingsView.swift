import SwiftUI
import TokenBarCore

/// Root of the native Settings window.
public struct SettingsView: View {
    let settings: AppSettings
    let store: UsageStore
    let launchAtLogin: LaunchAtLogin

    @AppStorage(SettingsTab.storageKey) private var tab = SettingsTab.general

    public init(settings: AppSettings, store: UsageStore, launchAtLogin: LaunchAtLogin) {
        self.settings = settings
        self.store = store
        self.launchAtLogin = launchAtLogin
    }

    public var body: some View {
        TabView(selection: $tab) {
            GeneralSettingsView(settings: settings, launchAtLogin: launchAtLogin)
                .tabItem {
                    Label(String(localized: "General", bundle: .module), systemImage: "gearshape")
                }
                .tag(SettingsTab.general)
            ProvidersSettingsView(settings: settings, store: store)
                .tabItem {
                    Label(String(localized: "Providers", bundle: .module), systemImage: "square.stack.3d.up")
                }
                .tag(SettingsTab.providers)
        }
        .frame(width: 500)
    }
}

/// Settings tabs. The selection is remembered, and the popover can choose one before opening Settings.
enum SettingsTab: String {
    case general
    case providers

    static let storageKey = "settingsTab"

    static func select(_ tab: SettingsTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: storageKey)
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
