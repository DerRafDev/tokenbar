import Foundation

/// Why a provider could not return usage.
///
/// Cases deliberately carry no free-form text, so response bodies, URLs, or tokens
/// can never leak into the UI or logs through an error.
public enum ProviderError: Error, Hashable, Sendable {
    /// No credentials are available (for example, the companion CLI is not signed in).
    case notConnected
    /// Credentials exist but were rejected or have expired.
    case unauthorized
    /// The provider asked us to slow down. `retryAfter` comes from `Retry-After` when present.
    case rateLimited(retryAfter: TimeInterval?)
    case offline
    case timedOut
    /// The response could not be understood, usually because the provider changed its format.
    case invalidResponse
    case server(statusCode: Int)
    case unknown

    /// Maps any error thrown by a provider to a `ProviderError`.
    public init(_ error: any Error) {
        switch error {
        case let error as ProviderError:
            self = error
        case let error as URLError:
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                self = .offline
            case .timedOut:
                self = .timedOut
            case .userAuthenticationRequired:
                self = .unauthorized
            case .badServerResponse, .cannotDecodeContentData, .cannotParseResponse:
                self = .invalidResponse
            default:
                self = .unknown
            }
        case is DecodingError:
            self = .invalidResponse
        default:
            self = .unknown
        }
    }

    /// Maps an HTTP status code to an error, or `nil` for success codes.
    public init?(httpStatus: Int, retryAfter: TimeInterval? = nil) {
        switch httpStatus {
        case 200..<300: return nil
        case 401, 403: self = .unauthorized
        case 429: self = .rateLimited(retryAfter: retryAfter)
        default: self = .server(statusCode: httpStatus)
        }
    }
}
