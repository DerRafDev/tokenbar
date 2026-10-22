import SwiftUI
import TokenBarCore

/// Content of the menu bar popover.
public struct UsagePopover: View {
    let store: UsageStore
    let formatter: UsageFormatter

    @State private var isVisible = false
    @Environment(\.openSettings) private var openSettings

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
        .padding(16)
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
            if store.descriptors.isEmpty {
                emptyState
            }
            ForEach(Array(store.descriptors.enumerated()), id: \.element.id) { index, descriptor in
                if index > 0 {
                    Divider().padding(.vertical, 16)
                }
                ProviderSection(
                    descriptor: descriptor,
                    state: store.state(for: descriptor.id),
                    policy: store.policy,
                    now: now,
                    formatter: formatter
                )
            }
            Divider().padding(.vertical, 12)
            footer(now: now)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No providers enabled", bundle: .module)
                .font(.headline)
            Text("Enable a provider in Settings.", bundle: .module)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func footer(now: Date) -> some View {
        HStack {
            Button {
                Task { await store.refreshAll(.manual) }
            } label: {
                Label(formatter.updatedDescription(store.lastUpdated, now: now), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(store.isRefreshing)
            .keyboardShortcut("r")
            .help(String(localized: "Refresh now", bundle: .module))

            Spacer()

            Menu {
                Button(String(localized: "Settings…", bundle: .module)) {
                    NSApp.activate()
                    openSettings()
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
        }
    }
}

#if DEBUG
#Preview("Demo data") {
    let store = UsageStore(providers: [MockUsageProvider.claude(), MockUsageProvider.chatGPT()])
    UsagePopover(store: store)
        .task { await store.refreshAll(.manual) }
}

#Preview("Errors") {
    let store = UsageStore(providers: [
        MockUsageProvider.claude(.failure(.notConnected)),
        MockUsageProvider.chatGPT(.failure(.offline)),
    ])
    UsagePopover(store: store)
        .task { await store.refreshAll(.manual) }
}

#Preview("Empty") {
    UsagePopover(store: UsageStore(providers: []))
}
#endif
