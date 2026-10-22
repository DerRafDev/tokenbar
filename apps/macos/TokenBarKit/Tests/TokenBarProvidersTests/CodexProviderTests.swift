import Foundation
import Testing
import TokenBarCore

@testable import TokenBarProviders

struct CodexProviderTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func provider(
        _ reply: FakeHTTPClient.Reply,
        credentials: FakeCodexCredentials = .valid()
    ) -> (CodexProvider, FakeHTTPClient) {
        let http = FakeHTTPClient(reply)
        return (CodexProvider(credentials: credentials, http: http, now: { [now] in now }), http)
    }

    @Test func fetchesAndMapsUsage() async throws {
        let (provider, http) = provider(.response(status: 200, body: try Fixture.data("usage-plus", in: "Codex")))

        let snapshot = try await provider.fetchUsage()

        #expect(snapshot.provider == "codex")
        #expect(snapshot.plan == "Plus")
        #expect(snapshot.fetchedAt == now)
        #expect(snapshot.limits.map(\.id) == ["session", "weekly"])
        #expect(http.requests.count == 1)
    }

    @Test func sendsTokenOnlyToChatGPTAndIdentifiesAsTokenBar() async throws {
        let (provider, http) = provider(.response(status: 200, body: try Fixture.data("usage-plus", in: "Codex")))
        _ = try await provider.fetchUsage()

        let request = try #require(http.requests.first)
        #expect(request.url?.absoluteString == "https://chatgpt.com/backend-api/wham/usage")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "ChatGPT-Account-Id") == "test-account")
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("TokenBar") == true)
        #expect(request.httpBody == nil)
    }

    @Test func omitsAccountHeaderWithoutAccountID() async throws {
        let (provider, http) = provider(
            .response(status: 200, body: try Fixture.data("usage-plus", in: "Codex")),
            credentials: .valid(accountID: nil)
        )
        _ = try await provider.fetchUsage()
        #expect(http.requests.first?.value(forHTTPHeaderField: "ChatGPT-Account-Id") == nil)
    }

    @Test func returnsPartialData() async throws {
        let (provider, _) = provider(.response(status: 200, body: try Fixture.data("usage-partial", in: "Codex")))
        let snapshot = try await provider.fetchUsage()
        #expect(snapshot.limits.map(\.id) == ["weekly"])
        #expect(snapshot.plan == "Free")
    }

    @Test(arguments: [401, 403])
    func mapsRejectedTokenToUnauthorized(status: Int) async {
        // An invalid or missing token gets HTTP 401 with a JSON `detail` message (observed).
        let body = #"{"detail": "Unauthorized"}"#
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
        let (provider, _) = provider(.response(status: 502, body: Data("<html>".utf8)))
        await #expect(throws: ProviderError.server(statusCode: 502)) { try await provider.fetchUsage() }
    }

    @Test func rejectsMalformedJSON() async {
        let (provider, _) = provider(.response(status: 200, body: Data("<html>challenge</html>".utf8)))
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
            credentials: FakeCodexCredentials(result: .failure(error))
        )
        await #expect(throws: error) { try await provider.fetchUsage() }
        #expect(http.requests.isEmpty)
    }

    @Test(arguments: [
        ("free", "Free"), ("go", "Go"), ("plus", "Plus"), ("pro", "Pro"), ("team", "Team"),
        ("business", "Business"), ("enterprise", "Enterprise"), ("edu", "Edu"), ("PLUS", "Plus"),
    ])
    func namesKnownPlans(type: String, expected: String) {
        #expect(CodexProvider.planName(type) == expected)
    }

    @Test func hidesUnknownPlans() {
        #expect(CodexProvider.planName("plan_from_the_future") == nil)
        #expect(CodexProvider.planName(nil) == nil)
    }

    @Test func isExperimentalWithItsOwnNotice() {
        let descriptor = CodexProvider().descriptor
        #expect(descriptor.id == "codex")
        #expect(descriptor.displayName == "Codex")
        #expect(descriptor.isExperimental)
        #expect(descriptor.experimentalNotice?.contains("not ChatGPT message limits") == true)
        #expect(descriptor.accessDescription?.contains("auth.json") == true)
        #expect(!descriptor.isDemo)
    }
}
