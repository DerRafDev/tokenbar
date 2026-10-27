import Foundation
import Testing
import TokenBarCore

@testable import TokenBarProviders

struct ClaudeProviderTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func provider(
        _ reply: FakeHTTPClient.Reply,
        credentials: FakeCredentials = .valid()
    ) -> (ClaudeProvider, FakeHTTPClient) {
        let http = FakeHTTPClient(reply)
        return (ClaudeProvider(credentials: credentials, http: http, now: { [now] in now }), http)
    }

    @Test func fetchesAndMapsUsage() async throws {
        let (provider, http) = provider(.response(status: 200, body: try Fixture.data("usage-pro")))

        let snapshot = try await provider.fetchUsage()

        #expect(snapshot.provider == "claude")
        #expect(snapshot.plan == "Pro")
        #expect(snapshot.fetchedAt == now)
        #expect(snapshot.limits.map(\.id) == ["session", "weekly"])
        #expect(http.requests.count == 1)
    }

    @Test func sendsTokenOnlyToAnthropicAndIdentifiesAsTokenBar() async throws {
        let (provider, http) = provider(.response(status: 200, body: try Fixture.data("usage-pro")))
        _ = try await provider.fetchUsage()

        let request = try #require(http.requests.first)
        #expect(request.url?.absoluteString == "https://api.anthropic.com/api/oauth/usage")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "oauth-2025-04-20")
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("TokenBar") == true)
    }

    @Test func returnsPartialData() async throws {
        let (provider, _) = provider(.response(status: 200, body: try Fixture.data("usage-partial")))
        #expect(try await provider.fetchUsage().limits.map(\.id) == ["weekly"])
    }

    @Test(arguments: [401, 403])
    func mapsRejectedTokenToUnauthorized(status: Int) async {
        let body =
            #"{"type":"error","error":{"type":"authentication_error","message":"OAuth access token is invalid."}}"#
        let (provider, _) = provider(.response(status: status, body: Data(body.utf8)))
        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
    }

    @Test func mapsRateLimitWithRetryAfterSeconds() async {
        let (provider, _) = provider(.response(status: 429, body: Data(), headers: ["Retry-After": "120"]))
        await #expect(throws: ProviderError.rateLimited(retryAfter: 120)) { try await provider.fetchUsage() }
    }

    @Test func mapsRateLimitWithRetryAfterDate() async {
        let header = "Fri, 15 Jan 2027 08:05:00 GMT"  // 300 s after `now`
        let (provider, _) = provider(.response(status: 429, body: Data(), headers: ["Retry-After": header]))
        await #expect(throws: ProviderError.rateLimited(retryAfter: 300)) { try await provider.fetchUsage() }
    }

    @Test func mapsRateLimitWithoutRetryAfter() async {
        let (provider, _) = provider(.response(status: 429, body: Data()))
        await #expect(throws: ProviderError.rateLimited(retryAfter: nil)) { try await provider.fetchUsage() }
    }

    @Test func mapsServerErrors() async {
        let (provider, _) = provider(.response(status: 503, body: Data("<html>".utf8)))
        await #expect(throws: ProviderError.server(statusCode: 503)) { try await provider.fetchUsage() }
    }

    @Test func rejectsMalformedJSON() async {
        let (provider, _) = provider(.response(status: 200, body: Data("{".utf8)))
        await #expect(throws: ProviderError.invalidResponse) { try await provider.fetchUsage() }
    }

    @Test(arguments: [
        (URLError.Code.timedOut, ProviderError.timedOut),
        (.notConnectedToInternet, .offline),
        (.cannotFindHost, .offline),
    ])
    func mapsTransportErrors(code: URLError.Code, expected: ProviderError) async {
        let (provider, _) = provider(.failure(code))
        let error = await #expect(throws: URLError.self) { try await provider.fetchUsage() }
        #expect(error.map(ProviderError.init) == expected)
    }

    @Test(arguments: [ProviderError.notConnected, .accessDenied])
    func doesNotCallEndpointWithoutCredentials(error: ProviderError) async {
        let (provider, http) = provider(
            .response(status: 200, body: Data()),
            credentials: FakeCredentials(result: .failure(error))
        )
        await #expect(throws: error) { try await provider.fetchUsage() }
        #expect(http.requests.isEmpty)
    }

    @Test func doesNotSendExpiredToken() async {
        let (provider, http) = provider(
            .response(status: 200, body: Data()),
            credentials: .valid(expiresAt: now.addingTimeInterval(-1))
        )
        await #expect(throws: ProviderError.unauthorized) { try await provider.fetchUsage() }
        #expect(http.requests.isEmpty)
    }

    @Test func sendsTokenThatIsStillValid() async throws {
        let (provider, http) = provider(
            .response(status: 200, body: try Fixture.data("usage-pro")),
            credentials: .valid(expiresAt: now.addingTimeInterval(5 * 60))
        )
        _ = try await provider.fetchUsage()
        #expect(http.requests.count == 1)
    }

    @Test(arguments: [("pro", "Pro"), ("max", "Max"), ("team", "Team"), ("enterprise", "Enterprise")])
    func namesKnownPlans(type: String, expected: String) {
        #expect(ClaudeProvider.planName(type) == expected)
    }

    @Test func hidesUnknownPlans() {
        #expect(ClaudeProvider.planName("free_trial_2030") == nil)
        #expect(ClaudeProvider.planName(nil) == nil)
    }

    @Test func isExperimentalWithItsOwnNotice() {
        let descriptor = ClaudeProvider().descriptor
        #expect(descriptor.isExperimental)
        #expect(descriptor.experimentalNotice?.contains("/usage") == true)
        #expect(descriptor.accessDescription?.contains("Keychain") == true)
        #expect(!descriptor.isDemo)
    }
}
