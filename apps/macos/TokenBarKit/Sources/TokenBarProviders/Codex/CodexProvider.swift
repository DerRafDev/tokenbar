import Foundation
import TokenBarCore
import os

/// Codex usage on a ChatGPT plan, read with the sign-in of a local Codex installation.
///
/// **Experimental.** The endpoint is the one the Codex apps use to show plan limits. OpenAI does
/// not document it for other apps, so it can change or disappear. It reports **Codex** limits, not
/// ChatGPT message limits. Everything Codex-specific lives in this folder; removing the provider
/// means removing it from the app's provider registry.
///
/// Per refresh: read Codex's `auth.json` → `GET /backend-api/wham/usage` → map windows by length.
/// The token is never stored, copied, refreshed, or logged. An expired token is rejected by the
/// server (HTTP 401) and reported as ``ProviderError/unauthorized``; Codex renews it the next time
/// it is used.
public struct CodexProvider: UsageProvider {
    public let descriptor = ProviderDescriptor(
        id: "codex",
        displayName: "Codex",
        symbolName: "chevron.left.forwardslash.chevron.right",
        experimentalNotice: String(
            localized: """
                TokenBar reads Codex usage from the endpoint the Codex apps use to show your plan's limits. \
                OpenAI does not document it for other apps: it may change or stop working at any time, \
                and OpenAI's terms may not cover this use. It shows Codex limits, not ChatGPT message limits.
                """,
            bundle: .module
        ),
        accessDescription: String(
            localized: """
                Requires Codex signed in with ChatGPT on this Mac. On each refresh TokenBar reads Codex's \
                sign-in from ~/.codex/auth.json and sends it only to chatgpt.com. \
                It is never stored, copied, or refreshed by TokenBar.
                """,
            bundle: .module
        )
    )

    static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    private let credentials: any CodexCredentialSource
    private let http: any HTTPClient
    private let now: @Sendable () -> Date
    private let logger = Logger(subsystem: Log.subsystem, category: "codex")

    public init() {
        self.init(credentials: CodexAuthFile(), http: URLSession.providerSession())
    }

    init(
        credentials: any CodexCredentialSource,
        http: any HTTPClient,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.credentials = credentials
        self.http = http
        self.now = now
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        let credentials = try credentials.credentials()

        let (data, response) = try await http.send(Self.request(credentials))
        // Only the status code is logged: the body contains the account's email and IDs.
        logger.debug("Usage request finished with HTTP \(response.statusCode, privacy: .public)")
        if let error = ProviderError(httpStatus: response.statusCode, retryAfter: response.retryAfter(now: now())) {
            throw error
        }

        let usage = try CodexUsageResponse.decode(data)
        let fetchedAt = now()
        return UsageSnapshot(
            provider: descriptor.id,
            plan: Self.planName(usage.planType),
            limits: usage.limits(fetchedAt: fetchedAt),
            fetchedAt: fetchedAt
        )
    }

    static func request(_ credentials: CodexCredentials) -> URLRequest {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID = credentials.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(HTTPHeaders.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    /// Display name for the response's `plan_type`. Unknown values are not shown.
    static func planName(_ planType: String?) -> String? {
        switch planType?.lowercased() {
        case "free": "Free"
        case "go": "Go"
        case "plus": "Plus"
        case "pro": "Pro"
        case "team": "Team"
        case "business": "Business"
        case "enterprise": "Enterprise"
        case "edu", "education": "Edu"
        default: nil
        }
    }
}
