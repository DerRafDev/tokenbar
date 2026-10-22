import Foundation
import Testing

@testable import TokenBarProviders

/// Runs against the real login Keychain, using a test-only service that is emptied around each test.
@Suite(.serialized)
struct KeychainCredentialStoreTests {
    let store = KeychainCredentialStore(service: "io.github.derrafdev.TokenBar.tests")
    let account = "test.token"

    init() throws {
        try store.delete(account)
    }

    @Test func readsNothingWhenEmpty() throws {
        #expect(try store.read(account) == nil)
    }

    @Test func roundTripsAndOverwrites() throws {
        defer { try? store.delete(account) }

        try store.write(Data("first".utf8), for: account)
        #expect(try store.read(account) == Data("first".utf8))

        try store.write(Data("second".utf8), for: account)
        #expect(try store.read(account) == Data("second".utf8))
    }

    @Test func deletes() throws {
        try store.write(Data("secret".utf8), for: account)
        try store.delete(account)
        #expect(try store.read(account) == nil)
        try store.delete(account)  // deleting a missing item is not an error
    }

    @Test func isolatesServices() throws {
        let other = KeychainCredentialStore(service: "io.github.derrafdev.TokenBar.tests.other")
        defer { try? store.delete(account) }

        try store.write(Data("secret".utf8), for: account)
        #expect(try other.read(account) == nil)
    }
}
