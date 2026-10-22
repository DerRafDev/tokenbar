import SwiftUI

/// Content of the menu bar popover.
public struct UsagePopover: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No providers connected", bundle: .module)
                .font(.headline)
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "Quit TokenBar", bundle: .module)) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding()
        .frame(width: 360)
    }
}

#Preview {
    UsagePopover()
}
