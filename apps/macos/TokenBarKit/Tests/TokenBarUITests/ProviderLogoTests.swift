import Testing
import TokenBarCore

@testable import TokenBarUI

struct ProviderLogoTests {
    @Test(arguments: [ProviderLogo.claude, ProviderLogo.openAI])
    func shipsEveryLogoAsAResource(logo: ProviderLogo) throws {
        let image = try #require(LogoImage.load(logo))
        #expect(image.size.width > 0 && image.size.width == image.size.height)
    }

    @Test func fallsBackToTheSymbolForUnknownLogos() {
        #expect(LogoImage.load(ProviderLogo(resourceName: "missing")) == nil)
    }
}
