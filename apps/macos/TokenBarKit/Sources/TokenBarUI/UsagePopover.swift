import SwiftUI
import TokenBarCore

/// Content of the menu bar popover: a compact overview of every enabled provider, where one
/// provider at a time can be expanded to show its details.
public struct UsagePopover: View {
    let store: UsageStore
    let formatter: UsageFormatter

    @State private var isVisible = false
    /// The provider the user expanded, or `nil` when they collapsed it. Only read once
    /// ``hasChosenExpansion`` is true; until then a lone provider starts expanded.
    @State private var expandedID: ProviderID?
    @State private var hasChosenExpansion = false
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(store: UsageStore, formatter: UsageFormatter = UsageFormatter()) {
        self.store = store
        self.formatter = formatter
    }

    public var body: some View {
        Group {
            // Countdowns tick once a minute, and only while the popover is on screen.
            if isVisible {
                TimelineView(.everyMinute) { context in
                    content(now: context.date)
                }
            } else {
                content(now: Date())
            }
        }
        // Rows add their own inner padding, so their content still lines up at `Spacing.large`.
        .padding(.horizontal, Spacing.small)
        .padding(.top, Spacing.small)
        .padding(.bottom, Spacing.medium)
        .frame(width: 360)
        .background(
            WindowVisibilityObserver { visible in
                isVisible = visible
                if visible {
                    Task { await store.refreshAll(.popoverOpened) }
                }
            }
        )
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.enabledDescriptors.isEmpty {
                emptyState
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(store.enabledDescriptors) { descriptor in
                    ProviderSection(
                        descriptor: descriptor,
                        state: store.state(for: descriptor.id),
                        policy: store.policy,
                        now: now,
                        formatter: formatter,
                        isExpanded: expanded == descriptor.id,
                        onToggle: { toggle(descriptor.id) }
                    )
                }
            }
            Divider()
                .padding(.horizontal, Spacing.small)
                .padding(.top, Spacing.small)
                .padding(.bottom, Spacing.small)
            footer(now: now)
                .padding(.horizontal, Spacing.small)
        }
    }

    private var expanded: ProviderID? {
        if hasChosenExpansion { return expandedID }
        let descriptors = store.enabledDescriptors
        return descriptors.count == 1 ? descriptors.first?.id : nil
    }

    /// Expands `id` and collapses any other provider, or collapses `id` if it is already open.
    private func toggle(_ id: ProviderID) {
        let next = expanded == id ? nil : id
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            expandedID = next
            hasChosenExpansion = true
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .padding(.bottom, Spacing.tight)
                .accessibilityHidden(true)
            Text("No providers enabled", bundle: .module)
                .font(.headline)
            Text("Turn on a provider to see its usage limits here.", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(String(localized: "Configure Providers…", bundle: .module)) {
                showSettings(.providers)
            }
            .buttonStyle(.link)
            .padding(.top, Spacing.tight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.medium)
        .padding(.top, Spacing.small)
    }

    private func footer(now: Date) -> some View {
        HStack {
            if !store.enabledDescriptors.isEmpty {
                refreshButton(now: now)
            }
            Spacer()

            Menu {
                Button(String(localized: "Settings…", bundle: .module)) {
                    showSettings()
                }
                .keyboardShortcut(",")
                Divider()
                Button(String(localized: "Quit TokenBar", bundle: .module)) {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(String(localized: "Settings", bundle: .module))
            .accessibilityLabel(Text("Settings", bundle: .module))
        }
        .font(.callout)
    }

    private func refreshButton(now: Date) -> some View {
        Button {
            Task { await store.refreshAll(.manual) }
        } label: {
            Label {
                Text(
                    store.isRefreshing
                        ? String(localized: "Updating…", bundle: .module)
                        : formatter.updatedDescription(store.lastUpdated, now: now)
                )
            } icon: {
                RefreshIcon(isRefreshing: store.isRefreshing)
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .disabled(store.isRefreshing)
        .keyboardShortcut("r")
        .help(String(localized: "Refresh now", bundle: .module))
        .accessibilityLabel(Text("Refresh now", bundle: .module))
        .accessibilityValue(formatter.updatedDescription(store.lastUpdated, now: now))
    }

    private func showSettings(_ tab: SettingsTab? = nil) {
        if let tab { SettingsTab.select(tab) }
        NSApp.activate()
        openSettings()
    }
}

/// The footer's refresh symbol. Spins while a refresh runs (macOS 15+, never with Reduce Motion).
private struct RefreshIcon: View {
    let isRefreshing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let image = Image(systemName: "arrow.clockwise")
        if #available(macOS 15, *) {
            image.symbolEffect(.rotate, options: .repeat(.continuous), isActive: isRefreshing && !reduceMotion)
        } else {
            image
        }
    }
}

#if DEBUG
#Preview("Demo data") {
    let store = UsageStore(providers: [MockUsageProvider.claude(), MockUsageProvider.codex()])
    UsagePopover(store: store)
        .task { await store.refreshAll(.manual) }
}

#Preview("Errors") {
    let store = UsageStore(providers: [
        MockUsageProvider.claude(.failure(.notConnected)),
        MockUsageProvider.codex(.failure(.offline)),
    ])
    UsagePopover(store: store)
        .task { await store.refreshAll(.manual) }
}

#Preview("Empty") {
    UsagePopover(store: UsageStore(providers: []))
}
#endif
