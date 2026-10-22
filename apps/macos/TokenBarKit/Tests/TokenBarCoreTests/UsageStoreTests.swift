import Foundation
import Testing

@testable import TokenBarCore

@MainActor
struct UsageStoreTests {
    let clock = TestClock()
    let policy = RefreshPolicy(interval: 300, fetchTimeout: 1, rateLimitBackoff: 600)

    private func makeStore(_ provider: StubProvider) -> UsageStore {
        UsageStore(providers: [provider], policy: policy, now: { [clock] in clock.now })
    }

    @Test func storesSnapshotOnSuccess() async {
        let provider = StubProvider(clock: clock, results: [.success([.session(0.17)])])
        let store = makeStore(provider)

        await store.refresh("stub", .manual)

        let state = store.state(for: "stub")
        #expect(state.snapshot?.limit(.session)?.usedFraction == 0.17)
        #expect(state.error == nil)
        #expect(!state.isRefreshing)
        #expect(!state.isStale(at: clock.now, policy: policy))
        #expect(store.lastUpdated == clock.now)
    }

    @Test func keepsLastSnapshotWhenRefreshFails() async {
        let provider = StubProvider(clock: clock, results: [.success([.session(0.4)]), .failure(.offline)])
        let store = makeStore(provider)

        await store.refresh("stub", .manual)
        clock.advance(by: 60)
        await store.refresh("stub", .manual)

        let state = store.state(for: "stub")
        #expect(state.snapshot?.limit(.session)?.usedFraction == 0.4)
        #expect(state.error == .offline)
        #expect(state.isStale(at: clock.now, policy: policy))
    }

    @Test func clearsSnapshotWhenProviderDisconnects() async {
        let provider = StubProvider(clock: clock, results: [.success([.session(0.4)]), .failure(.notConnected)])
        let store = makeStore(provider)

        await store.refresh("stub", .manual)
        await store.refresh("stub", .manual)

        #expect(store.state(for: "stub").snapshot == nil)
        #expect(store.state(for: "stub").error == .notConnected)
    }

    @Test func marksOldDataStale() async {
        let provider = StubProvider(clock: clock, results: [.success([.session(0.4)])])
        let store = makeStore(provider)
        await store.refresh("stub", .manual)

        clock.advance(by: policy.staleAfter)
        #expect(!store.state(for: "stub").isStale(at: clock.now, policy: policy))
        clock.advance(by: 1)
        #expect(store.state(for: "stub").isStale(at: clock.now, policy: policy))
    }

    @Test func honorsRetryAfterForEveryTrigger() async {
        let provider = StubProvider(
            clock: clock,
            results: [.failure(.rateLimited(retryAfter: 120)), .success([.session(0.2)])]
        )
        let store = makeStore(provider)

        await store.refresh("stub", .manual)
        clock.advance(by: 119)
        await store.refresh("stub", .manual)
        #expect(provider.callCount == 1)

        clock.advance(by: 1)
        await store.refresh("stub", .manual)
        #expect(provider.callCount == 2)
        #expect(store.state(for: "stub").error == nil)
        #expect(store.state(for: "stub").retryNotBefore == nil)
    }

    @Test func usesDefaultBackoffWithoutRetryAfter() async {
        let provider = StubProvider(clock: clock, results: [.failure(.rateLimited(retryAfter: nil))])
        let store = makeStore(provider)

        await store.refresh("stub", .manual)

        #expect(store.state(for: "stub").retryNotBefore == clock.now.addingTimeInterval(600))
    }

    @Test func coalescesConcurrentRefreshes() async {
        let provider = StubProvider(clock: clock, latency: .milliseconds(100), results: [.success([.session(0.1)])])
        let store = makeStore(provider)

        async let first: Void = store.refresh("stub", .manual)
        async let second: Void = store.refresh("stub", .manual)
        async let all: Void = store.refreshAll(.manual)
        _ = await (first, second, all)

        #expect(provider.callCount == 1)
    }

    @Test func popoverOpenSkipsFreshData() async {
        let provider = StubProvider(clock: clock, results: [.success([.session(0.1)])])
        let store = makeStore(provider)
        await store.refresh("stub", .manual)

        clock.advance(by: policy.interval - 1)
        await store.refresh("stub", .popoverOpened)
        #expect(provider.callCount == 1)

        clock.advance(by: 1)
        await store.refresh("stub", .popoverOpened)
        #expect(provider.callCount == 2)
    }

    @Test func scheduledRefreshSkipsDataFromRecentManualRefresh() async {
        let provider = StubProvider(clock: clock, results: [.success([.session(0.1)])])
        let store = makeStore(provider)
        await store.refresh("stub", .manual)

        clock.advance(by: policy.interval / 2 - 1)
        await store.refresh("stub", .scheduled)
        #expect(provider.callCount == 1)

        clock.advance(by: 1)
        await store.refresh("stub", .scheduled)
        #expect(provider.callCount == 2)
    }

    @Test func retriesImmediatelyAfterFailure() async {
        let provider = StubProvider(clock: clock, results: [.failure(.offline), .success([.session(0.1)])])
        let store = makeStore(provider)

        await store.refresh("stub", .manual)
        await store.refresh("stub", .popoverOpened)

        #expect(provider.callCount == 2)
        #expect(store.state(for: "stub").error == nil)
    }

    @Test func timesOutSlowProviders() async {
        let provider = StubProvider(clock: clock, latency: .seconds(5), results: [.success([.session(0.1)])])
        let store = makeStore(provider)

        await store.refresh("stub", .manual)

        #expect(store.state(for: "stub").error == .timedOut)
    }

    @Test func acceptsPartialData() async {
        let provider = StubProvider(clock: clock, results: [.success([])])
        let store = makeStore(provider)

        await store.refresh("stub", .manual)

        #expect(store.state(for: "stub").snapshot?.limits.isEmpty == true)
        #expect(store.state(for: "stub").error == nil)
    }

    @Test func ignoresUnknownProvider() async {
        let provider = StubProvider(clock: clock, results: [.success([])])
        let store = makeStore(provider)

        await store.refresh("missing", .manual)

        #expect(provider.callCount == 0)
        #expect(store.states.isEmpty)
    }
}
