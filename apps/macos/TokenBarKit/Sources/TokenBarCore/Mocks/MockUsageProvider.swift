#if DEBUG
import Foundation

/// Provider that returns made-up data, for development, previews, and tests.
///
/// Compiled into Debug builds only. Its descriptor is marked ``ProviderDescriptor/isDemo``
/// so the UI always labels its data as a demo.
public struct MockUsageProvider: UsageProvider {
    public struct Limit: Sendable {
        let id: String
        let window: LimitWindow
        let scope: String?
        let usedFraction: Double?
        /// Reset time relative to the fetch, so the data looks live.
        let resetsIn: TimeInterval?

        public init(
            _ window: LimitWindow,
            scope: String? = nil,
            used: Double?,
            resetsIn: TimeInterval?,
            id: String? = nil
        ) {
            self.id = id ?? [Self.key(for: window), scope?.lowercased()].compactMap(\.self).joined(separator: ".")
            self.window = window
            self.scope = scope
            self.usedFraction = used
            self.resetsIn = resetsIn
        }

        private static func key(for window: LimitWindow) -> String {
            switch window {
            case .session: "session"
            case .rolling(let length): "rolling.\(length.components.seconds)s"
            case .daily: "daily"
            case .weekly: "weekly"
            case .monthly: "monthly"
            }
        }
    }

    public enum Behavior: Sendable {
        case success(plan: String?, limits: [Limit])
        case failure(ProviderError)
    }

    public let descriptor: ProviderDescriptor
    let behavior: Behavior
    let latency: Duration

    public init(
        id: ProviderID,
        name: String,
        symbolName: String = "sparkle",
        experimental: Bool = false,
        behavior: Behavior,
        latency: Duration = .milliseconds(300)
    ) {
        self.descriptor = ProviderDescriptor(
            id: id,
            displayName: name,
            symbolName: symbolName,
            isDemo: true,
            experimentalNotice: experimental
                ? "Demo of an experimental provider. The real one relies on an undocumented source." : nil,
            accessDescription: "Demo data. Nothing is read from your Mac."
        )
        self.behavior = behavior
        self.latency = latency
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        try await Task.sleep(for: latency)
        return try snapshot(at: Date())
    }

    /// The snapshot this provider would return at `date`, without waiting. Useful for previews.
    public func snapshot(at date: Date) throws -> UsageSnapshot {
        switch behavior {
        case .failure(let error):
            throw error
        case .success(let plan, let limits):
            return UsageSnapshot(
                provider: descriptor.id,
                plan: plan,
                limits: limits.map {
                    UsageLimit(
                        id: $0.id,
                        window: $0.window,
                        scope: $0.scope,
                        usedFraction: $0.usedFraction,
                        resetsAt: $0.resetsIn.map(date.addingTimeInterval)
                    )
                },
                fetchedAt: date
            )
        }
    }
}

extension MockUsageProvider {
    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 60 * minute
    private static let day: TimeInterval = 24 * hour

    /// Claude-like sample data matching the design mockup. Experimental, like the real provider.
    public static func claude(_ behavior: Behavior? = nil) -> MockUsageProvider {
        MockUsageProvider(
            id: "claude",
            name: "Claude",
            symbolName: "asterisk",
            experimental: true,
            behavior: behavior
                ?? .success(
                    plan: "Pro",
                    limits: [
                        Limit(.session, used: 0.17, resetsIn: 2 * hour + 50 * minute),
                        Limit(.weekly, used: 0.79, resetsIn: 2 * day + 14 * hour),
                    ]
                )
        )
    }

    /// Codex-like sample data: a 5-hour session and a weekly limit. Experimental, like the real provider.
    public static func codex(_ behavior: Behavior? = nil) -> MockUsageProvider {
        MockUsageProvider(
            id: "codex",
            name: "Codex",
            symbolName: "chevron.left.forwardslash.chevron.right",
            experimental: true,
            behavior: behavior
                ?? .success(
                    plan: "Plus",
                    limits: [
                        Limit(.session, used: 0.12, resetsIn: 2 * hour + 22 * minute),
                        Limit(.weekly, used: 0.42, resetsIn: 4 * day + 8 * hour),
                    ]
                )
        )
    }
}
#endif
