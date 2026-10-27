import Foundation
import TokenBarCore
import os

/// Claude Pro/Max usage, read with the sign-in of a local Claude Code installation.
///
/// **Experimental.** The endpoint is the one behind Claude Code's `/usage` command. Anthropic does
/// not document it for other apps, so it can change or disappear. Everything Claude-specific lives
/// in this folder; removing the provider means removing it from the app's provider registry.
///
/// Per refresh: Claude Code's sign-in (from memory, or its Keychain item when needed, see
/// ``ClaudeCredentialCache``) → `GET /api/oauth/usage` → map windows.
/// The token is kept in memory only, and never written to disk, refreshed, or logged. An expired or
/// rejected token is reported as ``ProviderError/unauthorized`` without calling the endpoint; Claude
/// Code renews it the next time it is used.
public struct ClaudeProvider: UsageProvider {
    public let descriptor = ProviderDescriptor(
        id: "claude",
        displayName: "Claude",
        symbolName: "asterisk",
        logo: .claude,
        experimentalNotice: String(
            localized: """
                TokenBar reads Claude usage from the endpoint behind Claude Code's /usage command. \
                Anthropic does not document it for other apps: it may change or stop working at any time, \
                and Anthropic's terms may not cover this use.
                """,
            bundle: .module
        ),
        accessDescription: String(
            localized: """
                Requires Claude Code signed in on this Mac. TokenBar reads Claude Code's sign-in from your \
                Keychain (macOS asks for permission) when it starts and when Claude Code renews it, keeps it \
                in memory only while TokenBar runs, and sends it only to api.anthropic.com. It is never \
                written to disk or refreshed by TokenBar.
                """,
            bundle: .module
        )
    )

    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    private let credentials: ClaudeCredentialCache
    private let http: any HTTPClient
    private let now: @Sendable () -> Date
    private let logger = Logger(subsystem: Log.subsystem, category: "claude")

    public init() {
        self.init(credentials: ClaudeCodeKeychain(), http: URLSession.providerSession())
    }

    init(
        credentials: any ClaudeCredentialSource,
        http: any HTTPClient,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.credentials = ClaudeCredentialCache(source: credentials, now: now)
        self.http = http
        self.now = now
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        let credentials = try await credentials.credentials()

        let (data, response) = try await http.send(Self.request(token: credentials.accessToken))
        // Only the status code is logged: the body and headers identify the account.
        logger.debug("Usage request finished with HTTP \(response.statusCode, privacy: .public)")
        if Self.isTokenRejected(status: response.statusCode, body: data) {
            await self.credentials.reject(credentials.accessToken)
        }
        if let error = ProviderError(httpStatus: response.statusCode, retryAfter: response.retryAfter(now: now())) {
            throw error
        }

        let usage = try ClaudeUsageResponse.decode(data)
        return UsageSnapshot(
            provider: descriptor.id,
            plan: Self.planName(credentials.subscriptionType),
            limits: usage.limits,
            fetchedAt: now()
        )
    }

    static func request(token: String) -> URLRequest {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(HTTPHeaders.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    /// True when the endpoint refused the token itself, as opposed to the account or organization.
    ///
    /// Matches Claude Code: every invalid or expired token gets HTTP 401 (`authentication_error`); a
    /// revoked one can get 403 with "OAuth token has been revoked". Other 403s (for example an
    /// organization that does not allow OAuth) keep the token.
    static func isTokenRejected(status: Int, body: Data) -> Bool {
        switch status {
        case 401: true
        case 403: String(decoding: body, as: UTF8.self).contains("OAuth token has been revoked")
        default: false
        }
    }

    /// Display name for Claude Code's `subscriptionType`. Unknown values are not shown.
    static func planName(_ subscriptionType: String?) -> String? {
        switch subscriptionType?.lowercased() {
        case "pro": "Pro"
        case "max": "Max"
        case "team": "Team"
        case "enterprise": "Enterprise"
        default: nil
        }
    }
}
