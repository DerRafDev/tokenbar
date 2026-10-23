import Foundation
import TokenBarCore
import os

/// Claude Pro/Max usage, read with the sign-in of a local Claude Code installation.
///
/// **Experimental.** The endpoint is the one behind Claude Code's `/usage` command. Anthropic does
/// not document it for other apps, so it can change or disappear. Everything Claude-specific lives
/// in this folder; removing the provider means removing it from the app's provider registry.
///
/// Per refresh: read Claude Code's Keychain item → `GET /api/oauth/usage` → map windows.
/// The token is never stored, copied, refreshed, or logged. An expired token is reported as
/// ``ProviderError/unauthorized`` without calling the endpoint; Claude Code renews it the next time
/// it is used.
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
                Requires Claude Code signed in on this Mac. On each refresh TokenBar reads Claude Code's \
                sign-in from your Keychain (macOS asks for permission) and sends it only to api.anthropic.com. \
                It is never stored, copied, or refreshed by TokenBar.
                """,
            bundle: .module
        )
    )

    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    private let credentials: any ClaudeCredentialSource
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
        self.credentials = credentials
        self.http = http
        self.now = now
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        let credentials = try credentials.credentials()
        guard !credentials.isExpired(at: now()) else {
            logger.info("Claude Code sign-in expired; not calling the endpoint")
            throw ProviderError.unauthorized
        }

        let (data, response) = try await http.send(Self.request(token: credentials.accessToken))
        // Only the status code is logged: the body and headers identify the account.
        logger.debug("Usage request finished with HTTP \(response.statusCode, privacy: .public)")
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
