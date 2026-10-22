import Foundation
import Testing

@testable import TokenBarCore

struct ProviderIDTests {
    @Test func encodesAsPlainString() throws {
        let data = try JSONEncoder().encode(ProviderID("claude"))
        #expect(String(decoding: data, as: UTF8.self) == "\"claude\"")
    }

    @Test func decodesFromPlainString() throws {
        let id = try JSONDecoder().decode(ProviderID.self, from: Data("\"chatgpt\"".utf8))
        #expect(id == "chatgpt")
    }
}
