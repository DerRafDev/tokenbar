import Foundation
import Observation
import os

/// Owns the usage state of every enabled provider and decides when to refresh it.
///
/// - Only enabled providers are ever asked for usage. Disabling a provider drops its data.
/// - Concurrent refreshes of the same provider are coalesced into one request.
/// - A failed refresh keeps the last good snapshot; the UI marks it as outdated.
/// - Rate limits are respected for every trigger, including manual refreshes.
@MainActor
@Observable
public final class UsageStore {
    /// Every registered provider, enabled or not, in display order.
    public let descriptors: [ProviderDescriptor]

    public var policy: RefreshPolicy {
        didSet {
            if policy.interval != oldValue.interval, scheduler != nil { startScheduledRefreshes() }
        }
    }

    /// Providers that may be refreshed. Newly enabled providers are refreshed right away.
    public var enabledProviders: Set<ProviderID> {
        didSet {
            guard enabledProviders != oldValue else { return }
            for id in oldValue.subtracting(enabledProviders) {
                inFlight[id]?.cancel()
                states[id] = nil
            }
            for id in enabledProviders.subtracting(oldValue) {
                Task { await refresh(id, .manual) }
            }
        }
    }

    public private(set) var states: [ProviderID: ProviderState] = [:]

    @ObservationIgnored private let providers: [ProviderID: any UsageProvider]
    @ObservationIgnored private var inFlight: [ProviderID: Task<Void, Never>] = [:]
    @ObservationIgnored private var scheduler: Task<Void, Never>?
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let logger = Logger(subsystem: Log.subsystem, category: "refresh")

    /// - Parameter enabledProviders: Providers allowed to refresh. `nil` enables all of them.
    public init(
        providers: [any UsageProvider],
        enabledProviders: Set<ProviderID>? = nil,
        policy: RefreshPolicy = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.descriptors = providers.map(\.descriptor)
        self.providers = Dictionary(providers.map { ($0.descriptor.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.enabledProviders = enabledProviders ?? Set(descriptors.map(\.id))
        self.policy = policy
        self.now = now
    }

    /// Enabled providers in display order.
    public var enabledDescriptors: [ProviderDescriptor] {
        descriptors.filter { enabledProviders.contains($0.id) }
    }

    public func state(for id: ProviderID) -> ProviderState {
        states[id] ?? ProviderState()
    }

    /// Time of the most recent successful fetch across all providers.
    public var lastUpdated: Date? {
        states.values.compactMap(\.snapshot?.fetchedAt).max()
    }

    public var isRefreshing: Bool {
        states.values.contains(where: \.isRefreshing)
    }

    public func refreshAll(_ trigger: RefreshTrigger) async {
        await withTaskGroup(of: Void.self) { group in
            for descriptor in enabledDescriptors {
                group.addTask { await self.refresh(descriptor.id, trigger) }
            }
        }
    }

    public func refresh(_ id: ProviderID, _ trigger: RefreshTrigger) async {
        if let running = inFlight[id] {
            await running.value
            return
        }
        guard let provider = providers[id], enabledProviders.contains(id),
            state(for: id).shouldRefresh(for: trigger, at: now(), policy: policy)
        else { return }

        let task = Task { await perform(provider) }
        inFlight[id] = task
        await task.value
        inFlight[id] = nil
    }

    /// Refreshes all enabled providers now and then on every policy interval, until
    /// ``stopScheduledRefreshes()``. Changing the interval restarts the schedule.
    ///
    /// Uses a sleep tolerance so macOS can coalesce the wakeup with other work.
    public func startScheduledRefreshes() {
        scheduler?.cancel()
        scheduler = Task {
            while !Task.isCancelled {
                await refreshAll(.scheduled)
                let interval = policy.interval
                try? await Task.sleep(for: .seconds(interval), tolerance: .seconds(interval / 10))
            }
        }
    }

    public func stopScheduledRefreshes() {
        scheduler?.cancel()
        scheduler = nil
    }

    private func perform(_ provider: any UsageProvider) async {
        let id = provider.descriptor.id
        var state = state(for: id)
        state.isRefreshing = true
        states[id] = state

        do {
            let snapshot = try await withTimeout(policy.fetchTimeout) { try await provider.fetchUsage() }
            state.snapshot = snapshot
            state.error = nil
            state.retryNotBefore = nil
            logger.debug("Refreshed \(id, privacy: .public): \(snapshot.limits.count) limits")
        } catch is CancellationError {
            // Shutting down; keep the previous state.
        } catch {
            let error = ProviderError(error)
            state.error = error
            switch error {
            case .notConnected, .accessDenied:
                // A disconnected provider must not keep showing old numbers as if they were live.
                state.snapshot = nil
            case .rateLimited(let retryAfter):
                state.retryNotBefore = now().addingTimeInterval(retryAfter ?? policy.rateLimitBackoff)
            default:
                break
            }
            logger.error("Refresh failed for \(id, privacy: .public): \(String(describing: error), privacy: .public)")
        }

        state.isRefreshing = false
        // Disabled while the request was running: its result must not bring the provider back.
        guard enabledProviders.contains(id) else { return }
        states[id] = state
    }
}

/// Runs `operation`, throwing ``ProviderError/timedOut`` if it takes longer than `seconds`.
func withTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw ProviderError.timedOut
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else { throw CancellationError() }
        return result
    }
}
