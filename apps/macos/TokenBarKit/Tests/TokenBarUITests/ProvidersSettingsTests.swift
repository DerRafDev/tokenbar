import Testing
import TokenBarCore

@testable import TokenBarUI

@MainActor
struct ProvidersSettingsTests {
    @Test func consentShowsProviderNoticeThenWhatIsRead() {
        let descriptor = ProviderDescriptor(
            id: "claude",
            displayName: "Claude",
            experimentalNotice: "Uses an undocumented endpoint.",
            accessDescription: "Reads the Claude Code sign-in from your Keychain."
        )

        #expect(descriptor.isExperimental)
        #expect(
            ProvidersSettingsView.consentMessage(for: descriptor)
                == "Uses an undocumented endpoint.\n\nReads the Claude Code sign-in from your Keychain."
        )
    }
}
