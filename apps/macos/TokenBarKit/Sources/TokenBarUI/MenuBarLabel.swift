import SwiftUI
import TokenBarCore

/// The status item: each provider's icon followed by "S 17% | W 79%", keys dimmed so the numbers stand out.
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
                .accessibilityLabel(items.map(\.spokenText).joined(separator: ". "))
        }
    }

    struct Item: Hashable {
        let symbolName: String
        let parts: [MenuBarSummary.Part]
        let spokenText: String
    }

    private var items: [Item] {
        store.enabledDescriptors.compactMap { descriptor in
            guard settings.showsInMenuBar(descriptor.id),
                let snapshot = store.state(for: descriptor.id).snapshot
            else { return nil }
            let parts = MenuBarSummary.parts(for: snapshot, formatter: formatter)
            guard !parts.isEmpty else { return nil }
            return Item(
                symbolName: descriptor.symbolName,
                parts: parts,
                spokenText: MenuBarSummary.spokenText(for: snapshot, name: descriptor.displayName, formatter: formatter)
            )
        }
    }

    /// Opacity of the limit keys ("S", "W") and separators. A template image keeps alpha, so they
    /// stay quieter than the numbers in light and dark menu bars alike.
    private static let keyOpacity = 0.55
    private static let separatorOpacity = 0.3

    static func render(_ items: [Item]) -> NSImage {
        let content = HStack(spacing: 12) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 4) {
                    Image(systemName: item.symbolName)
                        .fontWeight(.semibold)
                    summary(item.parts)
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

    private static func summary(_ parts: [MenuBarSummary.Part]) -> Text {
        parts.enumerated().reduce(Text(verbatim: "")) { text, element in
            let (index, part) = element
            let separator =
                index == 0
                ? Text(verbatim: "") : Text(verbatim: " | ").foregroundStyle(.black.opacity(separatorOpacity))
            return text + separator
                + Text(verbatim: "\(part.label) ").fontWeight(.regular).foregroundStyle(.black.opacity(keyOpacity))
                + Text(verbatim: part.value)
        }
    }
}
