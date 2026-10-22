import Foundation
import Observation
import os

/// Owns the usage state of every enabled provider and decides when to refresh it.
///
/// - Concurrent refreshes of the same provider are coalesced into one request.
/// - A failed refresh keeps the last good snapshot; the UI marks it as outdated.
/// - Rate limits are respected for every trigger, including manual refreshes.
@MainActor
@Observable
public final class UsageStore {
    public let descriptors: [ProviderDescriptor]
    public var policy: RefreshPolicy
    public private(set) var states: [ProviderID: ProviderState] = [:]

    @ObservationIgnored private let providers: [ProviderID: any UsageProvider]
    @ObservationIgnored private var inFlight: [ProviderID: Task<Void, Never>] = [:]
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let logger = Logger(subsystem: Log.subsystem, category: "refresh")

    public init(
        providers: [any UsageProvider],
        policy: RefreshPolicy = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.descriptors = providers.map(\.descriptor)
        self.providers = Dictionary(providers.map { ($0.descriptor.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.policy = policy
        self.now = now
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
            for descriptor in descriptors {
                group.addTask { await self.refresh(descriptor.id, trigger) }
            }
        }
    }

    public func refresh(_ id: ProviderID, _ trigger: RefreshTrigger) async {
        if let running = inFlight[id] {
            await running.value
            return
        }
        guard let provider = providers[id],
            state(for: id).shouldRefresh(for: trigger, at: now(), policy: policy)
        else { return }

        let task = Task { await perform(provider) }
        inFlight[id] = task
        await task.value
        inFlight[id] = nil
    }

    /// Refreshes on the policy interval until the calling task is cancelled.
    ///
    /// Uses a sleep tolerance so macOS can coalesce the wakeup with other work.
    public func runScheduledRefreshes() async {
        while !Task.isCancelled {
            await refreshAll(.scheduled)
            let interval = policy.interval
            try? await Task.sleep(for: .seconds(interval), tolerance: .seconds(interval / 10))
        }
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
            case .notConnected:
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
