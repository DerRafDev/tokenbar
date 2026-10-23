import SwiftUI
import TokenBarCore

struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    let launchAtLogin: LaunchAtLogin
    var formatter = UsageFormatter()

    var body: some View {
        Form {
            Section {
                Toggle(
                    String(localized: "Open at login", bundle: .module),
                    isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) })
                )
                if launchAtLogin.requiresApproval {
                    approvalNote
                } else if launchAtLogin.lastChangeFailed {
                    Text(
                        "Could not change this setting. Try again in System Settings › General › Login Items.",
                        bundle: .module
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker(String(localized: "Refresh every", bundle: .module), selection: $settings.refreshInterval) {
                    ForEach(RefreshPolicy.intervalChoices, id: \.self) { interval in
                        Text(formatter.duration(interval)).tag(interval)
                    }
                }
            }

            Section {
                Toggle(
                    String(localized: "Show usage in menu bar", bundle: .module), isOn: $settings.showsUsageInMenuBar)
                Picker(String(localized: "Display", bundle: .module), selection: $settings.menuBarDisplay) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .disabled(!settings.showsUsageInMenuBar)
            } header: {
                Text("Menu Bar", bundle: .module)
            } footer: {
                Text(
                    settings.showsUsageInMenuBar
                        ? settings.menuBarDisplay.explanation
                        : String(localized: "When off, the menu bar shows only the TokenBar icon.", bundle: .module)
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { launchAtLogin.refresh() }
    }

    private var approvalNote: some View {
        HStack {
            Text("Allow TokenBar in Login Items to open it at login.", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button(String(localized: "Open Login Items…", bundle: .module)) {
                launchAtLogin.openSystemSettings()
            }
        }
    }
}

extension MenuBarDisplayMode {
    var title: String {
        switch self {
        case .providers: String(localized: "Providers", bundle: .module)
        case .minimal: String(localized: "Minimal", bundle: .module)
        case .detailed: String(localized: "Detailed", bundle: .module)
        }
    }

    /// What the mode shows, under the picker.
    var explanation: String {
        switch self {
        case .providers:
            String(
                localized:
                    "Each provider's highest usage. Switches to Minimal when there are too many providers to fit.",
                bundle: .module)
        case .minimal:
            String(localized: "Only the provider closest to its limit.", bundle: .module)
        case .detailed:
            String(
                localized: "The two main limits of each provider, such as 15/12 for session and week.",
                bundle: .module)
        }
    }
}
