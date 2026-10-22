import SwiftUI

/// Root of the native Settings window.
public struct SettingsView: View {
    public init() {}

    public var body: some View {
        TabView {
            Form {
                Text("General settings will appear here.", bundle: .module)
            }
            .formStyle(.grouped)
            .tabItem {
                Label(String(localized: "General", bundle: .module), systemImage: "gearshape")
            }
        }
        .frame(width: 460, height: 320)
    }
}

#Preview {
    SettingsView()
}
