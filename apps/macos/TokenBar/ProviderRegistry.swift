import Foundation
import TokenBarCore
import TokenBarProviders

/// The single place that decides which providers the app runs.
enum ProviderRegistry {
    struct Configuration {
        let providers: [any UsageProvider]
        /// Where settings are stored. Demo mode keeps its own, so it never touches real preferences.
        let defaults: UserDefaults
        /// Enabled until the user changes the selection. Real providers always start disabled.
        let initiallyEnabled: Set<ProviderID>
    }

    static func make() -> Configuration {
        #if DEBUG
        // Opt-in demo data for UI work: pass `-TokenBarUseMocks YES` (enabled in the shared scheme).
        if UserDefaults.standard.bool(forKey: "TokenBarUseMocks"),
            let defaults = UserDefaults(suiteName: "io.github.derrafdev.TokenBar.demo")
        {
            let providers = [MockUsageProvider.claude(), MockUsageProvider.codex()]
            return Configuration(
                providers: providers,
                defaults: defaults,
                initiallyEnabled: Set(providers.map(\.descriptor.id))
            )
        }
        #endif
        // Every real provider starts disabled; the user enables it in Settings (see docs/roadmap.md).
        return Configuration(providers: [ClaudeProvider()], defaults: .standard, initiallyEnabled: [])
    }
}
