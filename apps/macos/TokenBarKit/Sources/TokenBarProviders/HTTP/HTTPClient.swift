import Foundation
import TokenBarCore

/// Sends one HTTP request. Providers depend on this instead of `URLSession` so tests never touch
/// the network.
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPClient {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        return (data, http)
    }

    /// A session for authenticated provider requests: nothing is written to disk.
    ///
    /// No response cache (authenticated usage data must not land in ~/Library/Caches), no cookies,
    /// no stored URL credentials.
    public static func providerSession(timeout: TimeInterval = 15) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = timeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}

extension HTTPURLResponse {
    /// `Retry-After` in seconds, from either delta-seconds or an HTTP date. `nil` when absent or invalid.
    public func retryAfter(now: Date = Date()) -> TimeInterval? {
        guard let value = value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces) else {
            return nil
        }
        if let seconds = TimeInterval(value) {
            return seconds >= 0 ? seconds : nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value).map { max($0.timeIntervalSince(now), 0) }
    }
}

/// HTTP header values TokenBar sends to every provider.
public enum HTTPHeaders {
    /// Identifies TokenBar honestly. Providers never impersonate another client.
    public static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version.map { "TokenBar/\($0)" } ?? "TokenBar"
    }
}
