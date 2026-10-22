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
            self.id = id ?? [window.rawValue, scope?.lowercased()].compactMap(\.self).joined(separator: ".")
            self.window = window
            self.scope = scope
            self.usedFraction = used
            self.resetsIn = resetsIn
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
        behavior: Behavior,
        latency: Duration = .milliseconds(300)
    ) {
        self.descriptor = ProviderDescriptor(id: id, displayName: name, symbolName: symbolName, isDemo: true)
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

    /// Claude-like sample data matching the design mockup.
    public static func claude(_ behavior: Behavior? = nil) -> MockUsageProvider {
        MockUsageProvider(
            id: "claude",
            name: "Claude",
            symbolName: "asterisk",
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

    /// ChatGPT-like sample data matching the design mockup.
    public static func chatGPT(_ behavior: Behavior? = nil) -> MockUsageProvider {
        MockUsageProvider(
            id: "chatgpt",
            name: "ChatGPT",
            symbolName: "circle.hexagongrid",
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
