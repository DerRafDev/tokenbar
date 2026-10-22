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
    /// True for providers that return made-up data. The UI labels their data as a demo.
    public let isDemo: Bool

    public init(id: ProviderID, displayName: String, isDemo: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.isDemo = isDemo
    }
}
