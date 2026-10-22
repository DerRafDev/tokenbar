/// A source of usage data for one AI tool.
///
/// Implementations translate a provider-specific response into a normalized
/// ``UsageSnapshot``. They own authentication and networking; nothing outside the
/// provider knows about endpoints or credentials.
///
/// Errors should be thrown as ``ProviderError``. Any other error is mapped to the
/// closest case by ``ProviderError/init(_:)``.
public protocol UsageProvider: Sendable {
    var descriptor: ProviderDescriptor { get }

    func fetchUsage() async throws -> UsageSnapshot
}

/// Static, user-facing information about a provider.
public struct ProviderDescriptor: Identifiable, Hashable, Sendable {
    public let id: ProviderID
    /// Name shown in the UI, such as "Claude".
    public let displayName: String
    /// SF Symbol shown next to the name. Use a neutral symbol, not a company logo (trademarks).
    public let symbolName: String
    /// True for providers that return made-up data. The UI labels their data as a demo.
    public let isDemo: Bool
    /// True when the data source is undocumented and may change or stop working. The UI labels
    /// the provider as experimental and asks for confirmation before enabling it.
    public let isExperimental: Bool
    /// What the provider reads to get usage, shown before the user enables it.
    /// For example: "Reads the Claude Code sign-in from your Keychain."
    public let accessDescription: String?

    public init(
        id: ProviderID,
        displayName: String,
        symbolName: String = "sparkle",
        isDemo: Bool = false,
        isExperimental: Bool = false,
        accessDescription: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.symbolName = symbolName
        self.isDemo = isDemo
        self.isExperimental = isExperimental
        self.accessDescription = accessDescription
    }
}
