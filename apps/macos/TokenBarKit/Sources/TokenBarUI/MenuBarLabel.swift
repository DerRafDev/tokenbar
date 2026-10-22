import SwiftUI
import TokenBarCore

/// The status item: each provider's icon followed by "S 17% | W 79%".
///
/// `MenuBarExtra` labels only render a single plain image or text and drop symbols embedded in
/// text, so the summary is rendered into a template image. macOS tints template images for light
/// and dark menu bars. The image is only re-rendered when the summary changes.
public struct MenuBarLabel: View {
    let store: UsageStore
    let settings: AppSettings
    let formatter: UsageFormatter

    public init(store: UsageStore, settings: AppSettings, formatter: UsageFormatter = UsageFormatter()) {
        self.store = store
        self.settings = settings
        self.formatter = formatter
    }

    public var body: some View {
        let items = settings.showsUsageInMenuBar ? self.items : []
        if items.isEmpty {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .accessibilityLabel(Text(verbatim: "TokenBar"))
        } else {
            Image(nsImage: Self.render(items))
                .accessibilityLabel(items.map { "\($0.name) \($0.summary)" }.joined(separator: ", "))
        }
    }

    struct Item: Hashable {
        let name: String
        let symbolName: String
        let summary: String
    }

    private var items: [Item] {
        store.enabledDescriptors.compactMap { descriptor in
            guard settings.showsInMenuBar(descriptor.id),
                let snapshot = store.state(for: descriptor.id).snapshot,
                let summary = MenuBarSummary.text(for: snapshot, formatter: formatter)
            else { return nil }
            return Item(name: descriptor.displayName, symbolName: descriptor.symbolName, summary: summary)
        }
    }

    private static func render(_ items: [Item]) -> NSImage {
        let content = HStack(spacing: 10) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 4) {
                    Image(systemName: item.symbolName)
                    Text(verbatim: item.summary)
                }
            }
        }
        .font(.system(size: 12, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(.black)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }
}
