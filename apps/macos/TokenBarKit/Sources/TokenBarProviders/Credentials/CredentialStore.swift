import Foundation
import Security

/// Secure storage for credentials that TokenBar owns, such as a token the user pastes in.
///
/// Credentials owned by another app (a CLI sign-in) are never stored here: providers read
/// them at fetch time and never copy them.
public protocol CredentialStore: Sendable {
    func read(_ account: String) throws -> Data?
    func write(_ data: Data, for account: String) throws
    /// Removes the credential. Succeeds if there is none.
    func delete(_ account: String) throws
}

/// Why the Keychain refused an operation. Carries only the status code, never item data.
public struct KeychainError: Error, Hashable, Sendable {
    public let status: OSStatus
}

/// ``CredentialStore`` backed by generic password items in the user's login Keychain.
///
/// Items are readable only while the Mac is unlocked after the first login, stay on this Mac
/// (no iCloud Keychain sync), and are scoped to `service`.
public struct KeychainCredentialStore: CredentialStore {
    public let service: String

    public init(service: String = "io.github.derrafdev.TokenBar") {
        self.service = service
    }

    public func read(_ account: String) throws -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError(status: status)
        }
    }

    public func write(_ data: Data, for account: String) throws {
        let query = baseQuery(account)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        guard status == errSecItemNotFound else {
            guard status == errSecSuccess else { throw KeychainError(status: status) }
            return
        }

        var item = query
        item[kSecValueData] = data
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
    }

    public func delete(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func baseQuery(_ account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false,
        ]
    }
}
