import Foundation
import Testing

@testable import TokenBarCore

struct ProviderErrorTests {
    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, ProviderError.offline),
        (.networkConnectionLost, .offline),
        (.cannotFindHost, .offline),
        (.timedOut, .timedOut),
        (.userAuthenticationRequired, .unauthorized),
        (.cannotParseResponse, .invalidResponse),
        (.unknown, .unknown),
    ])
    func mapsURLErrors(code: URLError.Code, expected: ProviderError) {
        #expect(ProviderError(URLError(code)) == expected)
    }

    @Test func keepsProviderErrors() {
        #expect(ProviderError(ProviderError.rateLimited(retryAfter: 30)) == .rateLimited(retryAfter: 30))
    }

    @Test func mapsDecodingErrorsToInvalidResponse() {
        struct Payload: Decodable { let value: Int }
        let error = #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Payload.self, from: Data("{}".utf8))
        }
        #expect(error.map(ProviderError.init) == .invalidResponse)
    }

    @Test func mapsHTTPStatus() {
        #expect(ProviderError(httpStatus: 200) == nil)
        #expect(ProviderError(httpStatus: 204) == nil)
        #expect(ProviderError(httpStatus: 401) == .unauthorized)
        #expect(ProviderError(httpStatus: 403) == .unauthorized)
        #expect(ProviderError(httpStatus: 429, retryAfter: 120) == .rateLimited(retryAfter: 120))
        #expect(ProviderError(httpStatus: 503) == .server(statusCode: 503))
    }
}
