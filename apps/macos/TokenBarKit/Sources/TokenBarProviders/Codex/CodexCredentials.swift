import Foundation
import TokenBarCore

/// The parts of the Codex sign-in that TokenBar needs, read fresh for every refresh.
///
/// Never stored, copied, refreshed, or logged by TokenBar. The description is redacted so the
/// token and account ID cannot leak through string interpolation.
struct CodexCredentials: Sendable, CustomStringConvertible {
    let accessToken: String
    /// The ChatGPT account (personal or workspace) Codex is signed in to. Sent so the usage is the
    /// one Codex shows; never shown or logged.
    let accountID: String?

    var description: String { "CodexCredentials(<redacted>)" }

    /// Parses Codex's `auth.json`.
    ///
    /// Only `tokens.access_token` and `tokens.account_id` are read. The refresh token, ID token,
    /// and any API key are never decoded. The access token is a JWT, but TokenBar does not decode
    /// it: an expired token is rejected by the server with HTTP 401, which is reported the same way.
    static func parse(_ data: Data) throws -> CodexCredentials {
        struct AuthFile: Decodable {
            struct Tokens: Decodable {
                let accessToken: String
                let accountId: String?
            }
            let tokens: Tokens?
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let tokens = try? decoder.decode(AuthFile.self, from: data).tokens,
            !tokens.accessToken.isEmpty
        else {
            // Signed in with an API key instead of ChatGPT, or Codex changed its format.
            throw ProviderError.notConnected
        }
        return CodexCredentials(
            accessToken: tokens.accessToken,
            accountID: tokens.accountId.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}

/// Where ``CodexProvider`` gets the Codex sign-in.
protocol CodexCredentialSource: Sendable {
    func credentials() throws -> CodexCredentials
}

/// Reads `auth.json` from the Codex home folder, where Codex keeps its sign-in by default.
///
/// TokenBar reads the file only; it never writes, moves, or deletes it. Codex installations
/// configured to keep the sign-in in the Keychain (`cli_auth_credentials_store = "keyring"`) have
/// no file and are reported as not connected.
struct CodexAuthFile: CodexCredentialSource {
    var url: URL

    init(url: URL = Self.defaultURL()) {
        self.url = url
    }

    /// `$CODEX_HOME/auth.json`, or `~/.codex/auth.json`, the same lookup Codex uses.
    static func defaultURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        let home =
            environment["CODEX_HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex", directoryHint: .isDirectory)
        return home.appending(path: "auth.json", directoryHint: .notDirectory)
    }

    func credentials() throws -> CodexCredentials {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError {
            switch error.code {
            case .fileReadNoSuchFile, .fileNoSuchFile:
                // Codex is not installed, signed out (`codex logout` deletes the file), or uses the Keychain.
                throw ProviderError.notConnected
            case .fileReadNoPermission:
                throw ProviderError.accessDenied
            default:
                throw ProviderError.unknown
            }
        }
        return try CodexCredentials.parse(data)
    }
}
