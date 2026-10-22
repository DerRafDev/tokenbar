import Foundation
import TokenBarCore

/// The single place that decides which providers the app runs.
enum ProviderRegistry {
    static func makeProviders() -> [any UsageProvider] {
        #if DEBUG
        // Opt-in demo data for UI work: pass `-TokenBarUseMocks YES` (enabled in the shared scheme).
        if UserDefaults.standard.bool(forKey: "TokenBarUseMocks") {
            return [MockUsageProvider.claude(), MockUsageProvider.codex()]
        }
        #endif
        // Real providers are added here as they ship (see docs/roadmap.md).
        return []
    }
}
