import Foundation
import Observation

/// User preferences, persisted in `UserDefaults`.
///
/// Holds no secrets: credentials go through `CredentialStore` (Keychain). Values read from
/// disk are validated, so a hand-edited or outdated preference can never break the app.
@MainActor
@Observable
public final class AppSettings {
    /// Time between scheduled refreshes. Always one of ``RefreshPolicy/intervalChoices``.
    public var refreshInterval: TimeInterval {
        didSet {
            if !RefreshPolicy.intervalChoices.contains(refreshInterval) {
                refreshInterval = RefreshPolicy.default.interval
            }
            defaults.set(refreshInterval, forKey: Key.refreshInterval)
        }
    }

    /// Whether the menu bar shows usage numbers, or only the TokenBar icon.
    public var showsUsageInMenuBar: Bool {
        didSet { defaults.set(showsUsageInMenuBar, forKey: Key.showsUsageInMenuBar) }
    }

    /// Providers the user turned on. Every provider starts disabled: TokenBar reads no
    /// other app's credentials until the user enables the provider that needs them.
    public private(set) var enabledProviders: Set<ProviderID> {
        didSet { defaults.set(enabledProviders.map(\.rawValue).sorted(), forKey: Key.enabledProviders) }
    }

    /// Enabled providers whose numbers are left out of the menu bar (still shown in the popover).
    public private(set) var providersHiddenFromMenuBar: Set<ProviderID> {
        didSet {
            defaults.set(providersHiddenFromMenuBar.map(\.rawValue).sorted(), forKey: Key.providersHiddenFromMenuBar)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let interval = defaults.double(forKey: Key.refreshInterval)
        refreshInterval =
            RefreshPolicy.intervalChoices.contains(interval) ? interval : RefreshPolicy.default.interval
        showsUsageInMenuBar = defaults.object(forKey: Key.showsUsageInMenuBar) as? Bool ?? true
        enabledProviders = Self.providerIDs(defaults, Key.enabledProviders)
        providersHiddenFromMenuBar = Self.providerIDs(defaults, Key.providersHiddenFromMenuBar)
    }

    public func isEnabled(_ id: ProviderID) -> Bool {
        enabledProviders.contains(id)
    }

    public func setEnabled(_ enabled: Bool, for id: ProviderID) {
        if enabled { enabledProviders.insert(id) } else { enabledProviders.remove(id) }
    }

    public func showsInMenuBar(_ id: ProviderID) -> Bool {
        !providersHiddenFromMenuBar.contains(id)
    }

    public func setShowsInMenuBar(_ shows: Bool, for id: ProviderID) {
        if shows { providersHiddenFromMenuBar.remove(id) } else { providersHiddenFromMenuBar.insert(id) }
    }

    private static func providerIDs(_ defaults: UserDefaults, _ key: String) -> Set<ProviderID> {
        Set((defaults.stringArray(forKey: key) ?? []).map(ProviderID.init(rawValue:)))
    }

    private enum Key {
        static let refreshInterval = "refreshInterval"
        static let showsUsageInMenuBar = "showsUsageInMenuBar"
        static let enabledProviders = "enabledProviders"
        static let providersHiddenFromMenuBar = "providersHiddenFromMenuBar"
    }
}
