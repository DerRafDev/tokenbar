import Foundation

/// Everything the UI needs to know about one provider.
public struct ProviderState: Hashable, Sendable {
    /// Last successful snapshot. Kept when later refreshes fail.
    public internal(set) var snapshot: UsageSnapshot?
    /// Error of the most recent refresh, or `nil` if it succeeded.
    public internal(set) var error: ProviderError?
    public internal(set) var isRefreshing: Bool
    /// Set after a rate limit. No refresh is attempted before this date.
    public internal(set) var retryNotBefore: Date?

    public init(
        snapshot: UsageSnapshot? = nil,
        error: ProviderError? = nil,
        isRefreshing: Bool = false,
        retryNotBefore: Date? = nil
    ) {
        self.snapshot = snapshot
        self.error = error
        self.isRefreshing = isRefreshing
        self.retryNotBefore = retryNotBefore
    }

    /// True when there is data but it should not be trusted as current:
    /// it is older than ``RefreshPolicy/staleAfter`` or the last refresh failed.
    public func isStale(at now: Date, policy: RefreshPolicy) -> Bool {
        guard let snapshot else { return false }
        return error != nil || now.timeIntervalSince(snapshot.fetchedAt) > policy.staleAfter
    }

    func shouldRefresh(for trigger: RefreshTrigger, at now: Date, policy: RefreshPolicy) -> Bool {
        if let retryNotBefore, retryNotBefore > now { return false }
        // Retrying would show the permission prompt again; only the user may ask for that.
        if error == .accessDenied, trigger != .manual { return false }
        guard let snapshot, error == nil else { return true }
        let age = now.timeIntervalSince(snapshot.fetchedAt)
        switch trigger {
        case .manual: return true
        case .scheduled: return age >= policy.interval / 2
        case .popoverOpened: return age >= policy.interval
        }
    }
}
