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

    private let reply: Reply
    private let recorded = OSAllocatedUnfairLock(initialState: [URLRequest]())

    init(_ reply: Reply) {
        self.reply = reply
    }

    var requests: [URLRequest] { recorded.withLock { $0 } }

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

struct FakeCredentials: ClaudeCredentialSource {
    var result: Result<ClaudeCodeCredentials, ProviderError>

    static func valid(expiresAt: Date? = nil, plan: String? = "pro") -> FakeCredentials {
        FakeCredentials(
            result: .success(
                ClaudeCodeCredentials(accessToken: "test-token", expiresAt: expiresAt, subscriptionType: plan)
            )
        )
    }

    func credentials() throws -> ClaudeCodeCredentials {
        try result.get()
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
