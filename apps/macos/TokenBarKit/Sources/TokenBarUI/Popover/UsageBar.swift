import SwiftUI

/// Horizontal usage bar. Static (no animation) to keep the popover cheap to render.
struct UsageBar: View {
    let fraction: Double?
    var dimmed = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                if let fraction, fraction > 0 {
                    Capsule()
                        .fill(Self.tint(for: fraction))
                        .frame(width: max(proxy.size.height, proxy.size.width * fraction))
                }
            }
        }
        .frame(height: 6)
        .opacity(dimmed ? 0.4 : 1)
        .accessibilityHidden(true)
    }

    static func tint(for fraction: Double) -> Color {
        switch fraction {
        case ..<0.7: .accentColor
        case ..<0.9: .orange
        default: .red
        }
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
