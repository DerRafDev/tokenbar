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
                Toggle(
                    String(localized: "Show usage in menu bar", bundle: .module), isOn: $settings.showsUsageInMenuBar)
            } footer: {
                Text("When off, the menu bar shows only the TokenBar icon.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
