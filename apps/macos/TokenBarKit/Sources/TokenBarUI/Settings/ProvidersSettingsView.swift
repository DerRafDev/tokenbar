import SwiftUI
import TokenBarCore

/// Lists every registered provider with its status and switches to enable it and show it in the menu bar.
///
/// Enabling an experimental provider requires confirming a warning first: those providers read
/// credentials owned by another app through an undocumented mechanism.
struct ProvidersSettingsView: View {
    let settings: AppSettings
    let store: UsageStore
    var formatter = UsageFormatter()

    @State private var pendingConsent: ProviderDescriptor?

    var body: some View {
        Form {
            if store.descriptors.isEmpty {
                Text("No providers are available in this version yet.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(store.descriptors) { descriptor in
                Section {
                    row(descriptor)
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .alert(
            pendingConsent.map { String(localized: "Enable \($0.displayName)?", bundle: .module) } ?? "",
            isPresented: Binding(get: { pendingConsent != nil }, set: { if !$0 { pendingConsent = nil } }),
            presenting: pendingConsent
        ) { descriptor in
            Button(String(localized: "Enable", bundle: .module)) {
                settings.setEnabled(true, for: descriptor.id)
            }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
        } message: { descriptor in
            Text(Self.consentMessage(for: descriptor))
        }
    }

    private func row(_ descriptor: ProviderDescriptor) -> some View {
        let isEnabled = settings.isEnabled(descriptor.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: descriptor.symbolName)
                    .font(.title3)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(descriptor.displayName).font(.headline)
                        if descriptor.isExperimental {
                            Badge(text: String(localized: "Experimental", bundle: .module), tint: .orange)
                        }
                        if descriptor.isDemo {
                            Badge(text: String(localized: "Demo", bundle: .module), tint: .orange)
                        }
                    }
                    Text(status(of: descriptor.id, isEnabled: isEnabled))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(
                    String(localized: "Enabled", bundle: .module),
                    isOn: Binding(
                        get: { isEnabled },
                        set: { enable in
                            if enable && descriptor.isExperimental {
                                pendingConsent = descriptor
                            } else {
                                settings.setEnabled(enable, for: descriptor.id)
                            }
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(String(localized: "Enable \(descriptor.displayName)", bundle: .module))
            }
            if let access = descriptor.accessDescription {
                Text(access)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Toggle(
                String(localized: "Show in menu bar", bundle: .module),
                isOn: Binding(
                    get: { settings.showsInMenuBar(descriptor.id) },
                    set: { settings.setShowsInMenuBar($0, for: descriptor.id) }
                )
            )
            .disabled(!isEnabled)
        }
        .padding(.vertical, 2)
    }

    private func status(of id: ProviderID, isEnabled: Bool) -> String {
        guard isEnabled else { return String(localized: "Off", bundle: .module) }
        let state = store.state(for: id)
        if let error = state.error { return ProviderSection.message(for: error) }
        if let snapshot = state.snapshot {
            return formatter.updatedDescription(snapshot.fetchedAt, now: Date())
        }
        return String(localized: "Checking…", bundle: .module)
    }

    static func consentMessage(for descriptor: ProviderDescriptor) -> String {
        let warning = String(
            localized: """
                \(descriptor.displayName) support is experimental. It relies on an undocumented mechanism \
                that may change or stop working at any time.
                """,
            bundle: .module
        )
        return [warning, descriptor.accessDescription].compactMap(\.self).joined(separator: "\n\n")
    }
}
