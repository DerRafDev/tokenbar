import Foundation
import Testing
import TokenBarCore

@testable import TokenBarProviders

struct CodexCredentialsTests {
    @Test func readsOnlyTheAccessTokenAndAccountID() throws {
        let json = """
            {"auth_mode": "chatgpt", "OPENAI_API_KEY": null,
             "tokens": {"id_token": "id", "access_token": "access", "refresh_token": "refresh", "account_id": "account"},
             "last_refresh": "2026-10-17T12:00:00.000000Z"}
            """
        let credentials = try CodexCredentials.parse(Data(json.utf8))

        #expect(credentials.accessToken == "access")
        #expect(credentials.accountID == "account")
    }

    @Test func accountIDIsOptional() throws {
        let credentials = try CodexCredentials.parse(Data(#"{"tokens": {"access_token": "access"}}"#.utf8))
        #expect(credentials.accountID == nil)
        let empty = try CodexCredentials.parse(Data(#"{"tokens": {"access_token": "a", "account_id": ""}}"#.utf8))
        #expect(empty.accountID == nil)
    }

    @Test(arguments: [
        #"{"auth_mode": "apikey", "OPENAI_API_KEY": "sk-test"}"#,  // API key sign-in: no plan usage
        #"{"tokens": null}"#,
        #"{"tokens": {"access_token": ""}}"#,
        #"{"tokens": {"refresh_token": "refresh"}}"#,
        "not json",
        "",
    ])
    func treatsAnythingButAChatGPTSignInAsNotConnected(json: String) {
        #expect(throws: ProviderError.notConnected) { try CodexCredentials.parse(Data(json.utf8)) }
    }

    @Test func descriptionDoesNotRevealSecrets() {
        let credentials = CodexCredentials(accessToken: "secret-token", accountID: "secret-account")
        #expect(!"\(credentials)".contains("secret"))
        #expect(!String(reflecting: credentials).contains("secret"))
    }
}

struct CodexAuthFileTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "tokenbar-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func readsTheAuthFile() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "auth.json")
        try Data(#"{"tokens": {"access_token": "access", "account_id": "account"}}"#.utf8).write(to: file)

        let credentials = try CodexAuthFile(url: file).credentials()
        #expect(credentials.accessToken == "access")
    }

    @Test func missingFileMeansNotConnected() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(throws: ProviderError.notConnected) {
            try CodexAuthFile(url: directory.appending(path: "auth.json")).credentials()
        }
    }

    @Test func unreadableFileMeansAccessDenied() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "auth.json")
        try Data("{}".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)

        #expect(throws: ProviderError.accessDenied) { try CodexAuthFile(url: file).credentials() }
    }

    @Test func defaultsToTheCodexHomeFolder() {
        let url = CodexAuthFile.defaultURL(environment: [:])
        #expect(url.path.hasSuffix("/.codex/auth.json"))
    }

    @Test func honorsCodexHome() {
        #expect(CodexAuthFile.defaultURL(environment: ["CODEX_HOME": "/tmp/codex"]).path == "/tmp/codex/auth.json")
        #expect(CodexAuthFile.defaultURL(environment: ["CODEX_HOME": ""]).path.hasSuffix("/.codex/auth.json"))
    }
}
