import Foundation
import Testing
import TokenBarCore
import os

@testable import TokenBarProviders

enum Fixture {
    static func data(_ name: String, in folder: String = "Claude") throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/\(folder)")
        )
        return try Data(contentsOf: url)
    }
}

/// HTTP client that returns a scripted response and records the requests it receives.
final class FakeHTTPClient: HTTPClient {
    enum Reply: Sendable {
        case response(status: Int, body: Data, headers: [String: String] = [:])
        case failure(URLError.Code)
    }

    private let scripted: OSAllocatedUnfairLock<Reply>
    private let recorded = OSAllocatedUnfairLock(initialState: [URLRequest]())

    init(_ reply: Reply) {
        scripted = OSAllocatedUnfairLock(initialState: reply)
    }

    var requests: [URLRequest] { recorded.withLock { $0 } }

    /// Reply to the next requests.
    var reply: Reply {
        get { scripted.withLock { $0 } }
        set { scripted.withLock { $0 = newValue } }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recorded.withLock { $0.append(request) }
        switch reply {
        case .response(let status, let body, let headers):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            return (body, response)
        case .failure(let code):
            throw URLError(code)
        }
    }
}

/// Claude Code sign-in source with a scripted result and modification date. Counts Keychain reads.
final class FakeCredentials: ClaudeCredentialSource {
    private struct State {
        var result: Result<ClaudeCodeCredentials, ProviderError>
        var version: Result<Date?, ProviderError>
        var reads = 0
    }

    private let state: OSAllocatedUnfairLock<State>

    init(
        result: Result<ClaudeCodeCredentials, ProviderError>,
        version: Result<Date?, ProviderError> = .success(Date(timeIntervalSince1970: 0))
    ) {
        state = OSAllocatedUnfairLock(initialState: State(result: result, version: version))
    }

    static func valid(expiresAt: Date? = nil, plan: String? = "pro") -> FakeCredentials {
        FakeCredentials(result: .success(.fake(expiresAt: expiresAt, plan: plan)))
    }

    /// Data reads so far: the reads that can show a macOS permission prompt.
    var reads: Int { state.withLock { $0.reads } }

    var result: Result<ClaudeCodeCredentials, ProviderError> {
        get { state.withLock { $0.result } }
        set { state.withLock { $0.result = newValue } }
    }

    var version: Result<Date?, ProviderError> {
        get { state.withLock { $0.version } }
        set { state.withLock { $0.version = newValue } }
    }

    /// Simulates Claude Code writing a new sign-in.
    func renew(token: String = "renewed-token", expiresAt: Date? = nil) {
        state.withLock {
            $0.result = .success(.fake(token: token, expiresAt: expiresAt))
            let current = (try? $0.version.get()) ?? nil
            $0.version = .success((current ?? Date(timeIntervalSince1970: 0)).addingTimeInterval(1))
        }
    }

    func credentials() throws -> ClaudeCodeCredentials {
        try state.withLock {
            $0.reads += 1
            return try $0.result.get()
        }
    }

    func modificationDate() throws -> Date? {
        try version.get()
    }
}

/// A clock that tests move forward.
final class TestClock: Sendable {
    private let current: OSAllocatedUnfairLock<Date>

    init(_ start: Date) {
        current = OSAllocatedUnfairLock(initialState: start)
    }

    var now: Date { current.withLock { $0 } }

    func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }
}

extension ClaudeCodeCredentials {
    static func fake(token: String = "test-token", expiresAt: Date? = nil, plan: String? = "pro") -> Self {
        ClaudeCodeCredentials(accessToken: token, expiresAt: expiresAt, subscriptionType: plan)
    }
}

struct FakeCodexCredentials: CodexCredentialSource {
    var result: Result<CodexCredentials, ProviderError>

    static func valid(accountID: String? = "test-account") -> FakeCodexCredentials {
        FakeCodexCredentials(result: .success(CodexCredentials(accessToken: "test-token", accountID: accountID)))
    }

    func credentials() throws -> CodexCredentials {
        try result.get()
    }
}
