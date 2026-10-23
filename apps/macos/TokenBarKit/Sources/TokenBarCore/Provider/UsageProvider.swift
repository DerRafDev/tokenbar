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
    /// SF Symbol shown next to the name when the provider has no ``logo``.
    public let symbolName: String
    /// The provider's own mark, shown instead of ``symbolName``.
    public let logo: ProviderLogo?
    /// True for providers that return made-up data. The UI labels their data as a demo.
    public let isDemo: Bool
    /// Set when the data source is undocumented and may change or stop working. Explains the
    /// provider's specific source and risk. The UI labels the provider as experimental and shows
    /// this text, which the user must confirm before the provider is enabled.
    public let experimentalNotice: String?
    /// What the provider reads to get usage, shown before the user enables it.
    /// For example: "Reads the Claude Code sign-in from your Keychain."
    public let accessDescription: String?

    public var isExperimental: Bool { experimentalNotice != nil }

    public init(
        id: ProviderID,
        displayName: String,
        symbolName: String = "sparkle",
        logo: ProviderLogo? = nil,
        isDemo: Bool = false,
        experimentalNotice: String? = nil,
        accessDescription: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.symbolName = symbolName
        self.logo = logo
        self.isDemo = isDemo
        self.experimentalNotice = experimentalNotice
        self.accessDescription = accessDescription
    }
}

/// A provider's logo, shipped as a vector PDF in the UI module's resources.
///
/// Used with the brand owner's mark as the provider's identity only; TokenBar is not affiliated
/// with the providers (see README).
public struct ProviderLogo: Hashable, Sendable {
    /// Resource name without extension, for example "claude" for `Logos/claude.pdf`.
    public let resourceName: String
    /// True to draw the logo in its brand colors. False to draw it in the text color, like a symbol.
    /// The menu bar always draws logos in the text color.
    public let keepsColors: Bool

    public init(resourceName: String, keepsColors: Bool = false) {
        self.resourceName = resourceName
        self.keepsColors = keepsColors
    }

    public static let claude = ProviderLogo(resourceName: "claude", keepsColors: true)
    public static let openAI = ProviderLogo(resourceName: "openai")
}
