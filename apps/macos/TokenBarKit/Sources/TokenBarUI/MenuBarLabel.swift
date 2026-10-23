import SwiftUI
import TokenBarCore

/// The status item: provider icons with their usage, in the mode chosen in Settings.
///
/// `MenuBarExtra` labels only render a single plain image or text and drop symbols embedded in
/// text, so the summary is rendered into a template image. macOS tints template images for light
/// and dark menu bars, which also means the image cannot use color: a limit that gets close is
/// marked by weight, and a critical one by a dot after its number.
///
/// macOS offers no reliable way to know how much room the menu bar has left, so the width is
/// capped instead: when the chosen mode renders wider than ``maxWidth``, the next more compact
/// mode is used (Detailed → Providers → Minimal).
public struct MenuBarLabel: View {
    let store: UsageStore
    let settings: AppSettings
    let formatter: UsageFormatter

    public init(store: UsageStore, settings: AppSettings, formatter: UsageFormatter = UsageFormatter()) {
        self.store = store
        self.settings = settings
        self.formatter = formatter
    }

    /// Widest the status item may get, in points. Fits about four providers in Providers mode.
    static let maxWidth: CGFloat = 220

    public var body: some View {
        let snapshots = settings.showsUsageInMenuBar ? self.snapshots : []
        if let image = Self.image(for: snapshots, mode: settings.menuBarDisplay, formatter: formatter) {
            Image(nsImage: image)
                .accessibilityLabel(
                    snapshots.map {
                        MenuBarSummary.spokenText(
                            for: $0.snapshot, name: $0.descriptor.displayName, formatter: formatter)
                    }
                    .joined(separator: ". ")
                )
        } else {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .accessibilityLabel(Text(verbatim: "TokenBar"))
        }
    }

    /// Enabled providers shown in the menu bar that have data, in display order.
    private var snapshots: [(descriptor: ProviderDescriptor, snapshot: UsageSnapshot)] {
        store.enabledDescriptors.compactMap { descriptor in
            guard settings.showsInMenuBar(descriptor.id),
                let snapshot = store.state(for: descriptor.id).snapshot
            else { return nil }
            return (descriptor, snapshot)
        }
    }

    struct Item: Hashable {
        let id: ProviderID
        let symbolName: String
        let logo: ProviderLogo?
        let values: [String]
        let level: UsageLevel
    }

    /// Renders the most detailed mode that fits, or `nil` when there is nothing to show.
    private static func image(
        for snapshots: [(descriptor: ProviderDescriptor, snapshot: UsageSnapshot)],
        mode: MenuBarDisplayMode,
        formatter: UsageFormatter
    ) -> NSImage? {
        let candidates = MenuBarSummary.fallbacks(for: mode)
        for candidate in candidates {
            let items = items(for: snapshots, mode: candidate, formatter: formatter)
            guard !items.isEmpty else { return nil }
            let image = render(items)
            if image.size.width <= maxWidth || candidate == candidates.last {
                return image
            }
        }
        return nil
    }

    static func items(
        for snapshots: [(descriptor: ProviderDescriptor, snapshot: UsageSnapshot)],
        mode: MenuBarDisplayMode,
        formatter: UsageFormatter
    ) -> [Item] {
        let items = snapshots.compactMap { descriptor, snapshot -> (Item, Double)? in
            let values = MenuBarSummary.values(for: snapshot, mode: mode, formatter: formatter)
            guard !values.isEmpty else { return nil }
            let item = Item(
                id: descriptor.id,
                symbolName: descriptor.symbolName,
                logo: descriptor.logo,
                values: values,
                level: MenuBarSummary.level(of: snapshot, mode: mode)
            )
            return (item, snapshot.headlineLimit?.usedFraction ?? -1)
        }
        guard mode == .minimal else { return items.map(\.0) }
        // `max(by:)` keeps the first of equal elements, so ties go to the provider listed first.
        return items.max { $0.1 < $1.1 }.map { [$0.0] } ?? []
    }

    /// Opacity of the "/" between values in Detailed mode. A template image keeps alpha, so it
    /// stays quieter than the numbers in light and dark menu bars alike.
    private static let separatorOpacity = 0.4

    static func render(_ items: [Item]) -> NSImage {
        let content = HStack(spacing: 10) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 4) {
                    icon(item)
                    values(item)
                        .fontWeight(weight(for: item.level))
                    if item.level == .critical {
                        Circle().frame(width: 5, height: 5)
                    }
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

    /// Quiet while usage is normal, heavier as a limit gets close.
    private static func weight(for level: UsageLevel) -> Font.Weight {
        switch level {
        case .normal: .medium
        case .attention: .semibold
        case .critical: .bold
        }
    }

    /// Logos are always drawn in the text color here, so the status item stays a template image.
    @ViewBuilder
    private static func icon(_ item: Item) -> some View {
        if let logo = item.logo, let image = LogoImage.load(logo) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
        } else {
            Image(systemName: item.symbolName)
                .fontWeight(.semibold)
        }
    }

    private static func values(_ item: Item) -> Text {
        item.values.enumerated().reduce(Text(verbatim: "")) { text, element in
            let (index, value) = element
            let separator =
                index == 0 ? Text(verbatim: "") : Text(verbatim: "/").foregroundStyle(.black.opacity(separatorOpacity))
            return text + separator + Text(verbatim: value)
        }
    }
}
