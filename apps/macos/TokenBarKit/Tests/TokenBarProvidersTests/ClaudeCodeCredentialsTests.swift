import Foundation
import Testing
import TokenBarCore

@testable import TokenBarProviders

struct ClaudeCodeCredentialsTests {
    /// Same shape as Claude Code's Keychain item, with fake values.
    let item = Data(
        #"""
        {"claudeAiOauth":{"accessToken":"fake-access","refreshToken":"fake-refresh","expiresAt":1800000000000,
        "refreshTokenExpiresAt":1900000000000,"scopes":["user:inference"],"subscriptionType":"max",
        "subscriptionTypeSource":"x","rateLimitTier":"x"},"organizationUuid":"00000000-0000-0000-0000-000000000000"}
        """#.utf8
    )

    @Test func readsOnlyTokenExpiryAndPlan() throws {
        let credentials = try ClaudeCodeCredentials.parse(item)
        #expect(credentials.accessToken == "fake-access")
        #expect(credentials.expiresAt == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(credentials.subscriptionType == "max")
    }

    @Test func detectsExpiry() throws {
        let credentials = try ClaudeCodeCredentials.parse(item)
        #expect(!credentials.isExpired(at: Date(timeIntervalSince1970: 1_799_999_999)))
        #expect(credentials.isExpired(at: Date(timeIntervalSince1970: 1_800_000_000)))
    }

    @Test func neverPrintsTheToken() throws {
        let credentials = try ClaudeCodeCredentials.parse(item)
        #expect(!"\(credentials)".contains("fake"))
        #expect(!String(reflecting: credentials).contains("fake"))
    }

    @Test(arguments: [
        "",
        "not json",
        #"{"apiKey":"x"}"#,
        #"{"claudeAiOauth":{"accessToken":""}}"#,
        #"{"claudeAiOauth":{"refreshToken":"x"}}"#,
    ])
    func treatsUnusableItemsAsNotConnected(json: String) {
        #expect(throws: ProviderError.notConnected) { try ClaudeCodeCredentials.parse(Data(json.utf8)) }
    }
}

/// Reads a real Keychain item written under a test-only service.
@Suite(.serialized)
struct ClaudeCodeKeychainTests {
    let service = "io.github.derrafdev.TokenBar.tests.claude-code"
    var store: KeychainCredentialStore { KeychainCredentialStore(service: service) }

    init() throws {
        try KeychainCredentialStore(service: service).delete("test")
    }

    @Test func readsItem() throws {
        defer { try? store.delete("test") }
        try store.write(Data(#"{"claudeAiOauth":{"accessToken":"fake","subscriptionType":"pro"}}"#.utf8), for: "test")

        let credentials = try ClaudeCodeKeychain(service: service).credentials()

        #expect(credentials.accessToken == "fake")
        #expect(credentials.expiresAt == nil)
    }

    @Test func missingItemMeansNotConnected() {
        #expect(throws: ProviderError.notConnected) { try ClaudeCodeKeychain(service: service).credentials() }
    }
}
