import Foundation
import Testing
import TokenBarCore

@testable import TokenBarProviders

/// How often ``ClaudeProvider`` reads Claude Code's Keychain item across refreshes.
struct ClaudeCredentialCacheTests {
    let clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))

    private func provider(
        _ source: FakeCredentials,
        reply: FakeHTTPClient.Reply? = nil
    ) throws -> (ClaudeProvider, FakeHTTPClient) {
        let http = FakeHTTPClient(try reply ?? .response(status: 200, body: Fixture.data("usage-pro")))
        return (ClaudeProvider(credentials: source, http: http, now: { [clock] in clock.now }), http)
    }

    private static let rejected = FakeHTTPClient.Reply.response(
        status: 401,
        body: Data(
            #"{"type":"error","error":{"type":"authentication_error","message":"OAuth access token is invalid."}}"#.utf8
        )
    )

    @Test func readsTheKeychainOnFirstFetch() async throws {
        let source = FakeCredentials.valid()
        let (provider, http) = try provider(source)

        _ = try await provider.fetchUsage()

        #expect(source.reads == 1)
        #expect(http.requests.count == 1)
    }

    @Test func reusesTheSignInOnLaterFetches() async throws {
        let source = FakeCredentials.valid(expiresAt: clock.now.addingTimeInterval(3600))
        let (provider, http) = try provider(source)

        for _ in 0..<3 {
            _ = try await provider.fetchUsage()
            clock.advance(by: 5 * 60)
        }

        #expect(source.reads == 1)
        #expect(http.requests.count == 3)
        #expect(http.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer test-token" })
    }

    @Test func readsAgainWhenClaudeCodeWritesTheItem() async throws {
        let source = FakeCredentials.valid()
        let (provider, http) = try provider(source)
        _ = try await provider.fetchUsage()

        source.renew()
        _ = try await provider.fetchUsage()

        #expect(source.reads == 2)
        #expect(http.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer renewed-token")
    }

    @Test func expiredSignInIsReadOnceThenRetriedAfterTheInterval() async throws {
        let source = FakeCredentials.valid(expiresAt: clock.now.addingTimeInterval(60 * 60))
        let (provider, http) = try provider(source)
        _ = try await provider.fetchUsage()

        // Expired, item unchanged: one read in case Claude Code renewed it in place.
        clock.advance(by: 60 * 60)
        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        #expect(source.reads == 2)

        // Still expired: no read, no request, until the retry interval passed.
        clock.advance(by: 5 * 60)
        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        #expect(source.reads == 2)
        #expect(http.requests.count == 1)

        // Renewed without the modification date changing: picked up after the interval.
        source.result = .success(.fake(token: "renewed-token", expiresAt: clock.now.addingTimeInterval(3600)))
        clock.advance(by: ClaudeCredentialCache.retryInterval)
        _ = try await provider.fetchUsage()
        #expect(source.reads == 3)
        #expect(http.requests.count == 2)
    }

    @Test func treatsTokenCloseToExpiryAsExpired() async throws {
        let source = FakeCredentials.valid(expiresAt: clock.now.addingTimeInterval(30))
        let (provider, http) = try provider(source)

        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        #expect(http.requests.isEmpty)
    }

    @Test func rejectedTokenIsNotSentAgain() async throws {
        let source = FakeCredentials.valid()
        let (provider, http) = try provider(source, reply: Self.rejected)

        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        #expect(source.reads == 1)
        #expect(http.requests.count == 1)

        // Item rewritten with the same token: read, but still not sent.
        source.version = .success(Date(timeIntervalSince1970: 42))
        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        #expect(source.reads == 2)
        #expect(http.requests.count == 1)

        // A new token recovers.
        source.renew()
        http.reply = .response(status: 200, body: try Fixture.data("usage-pro"))
        _ = try await provider.fetchUsage()
        #expect(source.reads == 3)
        #expect(http.requests.count == 2)
    }

    @Test func rejectedTokenRecoversAfterTheIntervalWhenTheItemLooksUnchanged() async throws {
        let source = FakeCredentials.valid()
        let (provider, http) = try provider(source, reply: Self.rejected)
        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }

        source.result = .success(.fake(token: "renewed-token"))
        http.reply = .response(status: 200, body: try Fixture.data("usage-pro"))
        clock.advance(by: ClaudeCredentialCache.retryInterval)
        _ = try await provider.fetchUsage()

        #expect(source.reads == 2)
        #expect(http.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer renewed-token")
    }

    @Test func revoked403RejectsTheToken() async throws {
        let source = FakeCredentials.valid()
        let (provider, http) = try provider(
            source,
            reply: .response(status: 403, body: Data("OAuth token has been revoked".utf8))
        )
        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        #expect(http.requests.count == 1)
    }

    @Test func other403KeepsTheToken() async throws {
        let body =
            #"{"type":"error","error":{"type":"permission_error","message":"OAuth authentication is currently not allowed for this organization."}}"#
        let source = FakeCredentials.valid()
        let (provider, http) = try provider(source, reply: .response(status: 403, body: Data(body.utf8)))

        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        #expect(source.reads == 1)
        #expect(http.requests.count == 2)
    }

    @Test func rejectingAnOlderTokenKeepsTheNewerOne() async throws {
        let source = FakeCredentials.valid()
        let cache = ClaudeCredentialCache(source: source, now: { [clock] in clock.now })
        _ = try await cache.credentials()
        source.renew()
        _ = try await cache.credentials()

        await cache.reject("test-token")

        #expect(try await cache.credentials().accessToken == "renewed-token")
        #expect(source.reads == 2)
    }

    @Test func concurrentFetchesShareOneRead() async throws {
        let source = FakeCredentials.valid()
        let (provider, http) = try provider(source)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { _ = try await provider.fetchUsage() }
            }
            try await group.waitForAll()
        }

        #expect(source.reads == 1)
        #expect(http.requests.count == 10)
    }

    @Test func signOutDropsTheCachedSignIn() async throws {
        let source = FakeCredentials.valid()
        let (provider, http) = try provider(source)
        _ = try await provider.fetchUsage()

        source.version = .failure(.notConnected)
        await #expect(throws: ProviderError.notConnected) { try await provider.fetchUsage() }
        #expect(http.requests.count == 1)

        // Signed in again (possibly another account): read fresh.
        source.renew()
        _ = try await provider.fetchUsage()
        #expect(source.reads == 2)
    }

    @Test func declinedAccessIsNotCachedSoAManualRefreshCanAskAgain() async throws {
        let source = FakeCredentials(result: .failure(.accessDenied))
        let (provider, http) = try provider(source)

        await #expect(throws: ProviderError.accessDenied) { try await provider.fetchUsage() }
        await #expect(throws: ProviderError.accessDenied) { try await provider.fetchUsage() }
        #expect(source.reads == 2)

        source.result = .success(.fake())
        _ = try await provider.fetchUsage()
        #expect(http.requests.count == 1)
    }

    @Test func failedReadIsRetriedOncePerInterval() async throws {
        let source = FakeCredentials(result: .failure(.unknown))
        let (provider, http) = try provider(source)

        await #expect(throws: ProviderError.unknown) { try await provider.fetchUsage() }
        await #expect(throws: ProviderError.unknown) { try await provider.fetchUsage() }
        #expect(source.reads == 1)

        source.result = .success(.fake())
        clock.advance(by: ClaudeCredentialCache.retryInterval)
        _ = try await provider.fetchUsage()
        #expect(source.reads == 2)
        #expect(http.requests.count == 1)
    }

    @Test func unknownModificationDateReusesTheCachedSignIn() async throws {
        let source = FakeCredentials(result: .success(.fake()), version: .success(nil))
        let (provider, http) = try provider(source)

        for _ in 0..<3 { _ = try await provider.fetchUsage() }

        #expect(source.reads == 1)
        #expect(http.requests.count == 3)
    }

    @Test func unknownModificationDateWithoutSignInReadsOncePerInterval() async throws {
        let source = FakeCredentials(result: .failure(.unknown), version: .success(nil))
        let (provider, _) = try provider(source)

        await #expect(throws: ProviderError.unknown) { try await provider.fetchUsage() }
        await #expect(throws: ProviderError.unknown) { try await provider.fetchUsage() }
        #expect(source.reads == 1)

        // The Keychain answers again: its modification date counts as a change and is read at once.
        source.result = .success(.fake())
        source.version = .success(Date(timeIntervalSince1970: 1))
        _ = try await provider.fetchUsage()
        #expect(source.reads == 2)
    }

    @Test func cacheLivesOnlyAsLongAsTheProvider() async throws {
        let source = FakeCredentials.valid()
        _ = try await provider(source).0.fetchUsage()
        _ = try await provider(source).0.fetchUsage()

        // A new provider (as after relaunching the app) starts with nothing cached.
        #expect(source.reads == 2)
    }
}
