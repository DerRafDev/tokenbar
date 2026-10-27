import Foundation
import Security
import TokenBarCore

/// The parts of Claude Code's sign-in that TokenBar needs.
///
/// Kept only in memory by ``ClaudeCredentialCache``; never written to disk, copied to another Keychain
/// item, refreshed, or logged by TokenBar. The description is redacted so the token cannot leak through
/// string interpolation.
struct ClaudeCodeCredentials: Sendable, CustomStringConvertible {
    let accessToken: String
    let expiresAt: Date?
    /// Plan as Claude Code recorded it: "pro", "max", "team", "enterprise".
    let subscriptionType: String?

    var description: String { "ClaudeCodeCredentials(<redacted>)" }

    func isExpired(at now: Date) -> Bool {
        expiresAt.map { $0 <= now } ?? false
    }

    /// Parses the JSON that Claude Code stores in its Keychain item.
    ///
    /// Only `claudeAiOauth.accessToken`, `expiresAt` (milliseconds since 1970), and
    /// `subscriptionType` are read. The refresh token is never decoded.
    static func parse(_ data: Data) throws -> ClaudeCodeCredentials {
        struct Item: Decodable {
            struct OAuth: Decodable {
                let accessToken: String
                let expiresAt: Double?
                let subscriptionType: String?
            }
            let claudeAiOauth: OAuth?
        }
        guard let oauth = try? JSONDecoder().decode(Item.self, from: data).claudeAiOauth,
            !oauth.accessToken.isEmpty
        else {
            // Claude Code changed its format, or signed in with something other than a Claude account.
            throw ProviderError.notConnected
        }
        return ClaudeCodeCredentials(
            accessToken: oauth.accessToken,
            expiresAt: oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            subscriptionType: oauth.subscriptionType
        )
    }
}

/// Where ``ClaudeProvider`` gets Claude Code's sign-in.
protocol ClaudeCredentialSource: Sendable {
    /// Reads the sign-in itself. macOS may ask the user for permission.
    func credentials() throws -> ClaudeCodeCredentials
    /// When Claude Code last wrote its sign-in, read without the secret so macOS does not ask.
    /// Throws ``ProviderError/notConnected`` when there is no sign-in; `nil` when it is unknown.
    func modificationDate() throws -> Date?
}

/// Reads the generic password item Claude Code keeps in the login Keychain.
///
/// macOS asks the user before TokenBar can read another app's item, and the user can deny it.
/// TokenBar reads the item only; it never writes, updates, or deletes it.
struct ClaudeCodeKeychain: ClaudeCredentialSource {
    var service = "Claude Code-credentials"

    func credentials() throws -> ClaudeCodeCredentials {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw ProviderError.notConnected }
            return try ClaudeCodeCredentials.parse(data)
        case errSecItemNotFound:
            throw ProviderError.notConnected
        case errSecUserCanceled, errSecAuthFailed:
            throw ProviderError.accessDenied
        default:
            // Includes errSecInteractionNotAllowed (Keychain locked): retried on the next refresh.
            throw ProviderError.unknown
        }
    }

    func modificationDate() throws -> Date? {
        // Attributes only: the item's data, and with it the permission prompt, is not touched.
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return (result as? [CFString: Any])?[kSecAttrModificationDate] as? Date
        case errSecItemNotFound:
            throw ProviderError.notConnected
        default:
            // Keychain locked or unavailable: the cache falls back to its own retry limit.
            return nil
        }
    }
}
