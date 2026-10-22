import Testing
import TokenBarCore

@testable import TokenBarUI

@MainActor
struct ProvidersSettingsTests {
    @Test func consentWarnsAboutUndocumentedSourceAndNamesWhatIsRead() {
        let descriptor = ProviderDescriptor(
            id: "claude",
            displayName: "Claude",
            isExperimental: true,
            accessDescription: "Reads the Claude Code sign-in from your Keychain."
        )

        let message = ProvidersSettingsView.consentMessage(for: descriptor)

        #expect(message.contains("Claude support is experimental"))
        #expect(message.contains("undocumented mechanism that may change or stop working"))
        #expect(message.hasSuffix("Reads the Claude Code sign-in from your Keychain."))
    }
}
