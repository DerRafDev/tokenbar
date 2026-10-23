import SwiftUI

/// Thin horizontal usage bar: a rounded fill on a faint track.
///
/// The fill uses the system accent color and turns orange, then red, as the limit gets close
/// (see ``UsageLevel``).
/// Value changes animate briefly (never with Reduce Motion); nothing animates while idle.
struct UsageBar: View {
    let fraction: Double?
    var dimmed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    static let height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(contrast == .increased ? 0.25 : 0.1))
                if let fraction, fraction > 0 {
                    Capsule()
                        .fill(Self.tint(for: fraction))
                        .frame(width: max(proxy.size.height, proxy.size.width * fraction))
                }
            }
        }
        .frame(height: Self.height)
        .opacity(dimmed ? 0.4 : 1)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: fraction)
        .accessibilityHidden(true)
    }

    static func tint(for fraction: Double) -> Color {
        UsageLevel(fraction).color ?? .accentColor
    }
}

#Preview {
    VStack(spacing: 12) {
        UsageBar(fraction: 0)
        UsageBar(fraction: 0.17)
        UsageBar(fraction: 0.79)
        UsageBar(fraction: 1)
        UsageBar(fraction: nil)
        UsageBar(fraction: 0.5, dimmed: true)
    }
    .padding()
    .frame(width: 300)
}
