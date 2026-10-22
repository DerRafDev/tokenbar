import Foundation
import Testing

@testable import TokenBarCore

/// Serialized because every test reuses one defaults suite. A fresh suite per test would leave
/// an empty plist behind in ~/Library/Preferences on every run.
@MainActor
@Suite(.serialized)
struct AppSettingsTests {
    let defaults: UserDefaults

    init() {
        let suite = "io.github.derrafdev.TokenBar.tests"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func startsWithSafeDefaults() {
        let settings = AppSettings(defaults: defaults)
        #expect(settings.refreshInterval == RefreshPolicy.default.interval)
        #expect(settings.showsUsageInMenuBar)
        #expect(settings.enabledProviders.isEmpty)
        #expect(!settings.isEnabled("claude"))
        #expect(settings.showsInMenuBar("claude"))
    }

    @Test func persistsChanges() {
        let settings = AppSettings(defaults: defaults)
        settings.refreshInterval = 10 * 60
        settings.showsUsageInMenuBar = false
        settings.setEnabled(true, for: "claude")
        settings.setEnabled(true, for: "codex")
        settings.setEnabled(false, for: "codex")
        settings.setShowsInMenuBar(false, for: "claude")

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.refreshInterval == 10 * 60)
        #expect(!reloaded.showsUsageInMenuBar)
        #expect(reloaded.enabledProviders == ["claude"])
        #expect(!reloaded.showsInMenuBar("claude"))
        #expect(reloaded.showsInMenuBar("codex"))
    }

    @Test func rejectsUnsupportedInterval() {
        let settings = AppSettings(defaults: defaults)
        settings.refreshInterval = 1
        #expect(settings.refreshInterval == RefreshPolicy.default.interval)
    }

    @Test func ignoresInvalidStoredValues() {
        defaults.set(-3, forKey: "refreshInterval")
        defaults.set("yes", forKey: "showsUsageInMenuBar")
        defaults.set(42, forKey: "enabledProviders")

        let settings = AppSettings(defaults: defaults)
        #expect(settings.refreshInterval == RefreshPolicy.default.interval)
        #expect(settings.showsUsageInMenuBar)
        #expect(settings.enabledProviders.isEmpty)
    }
}
