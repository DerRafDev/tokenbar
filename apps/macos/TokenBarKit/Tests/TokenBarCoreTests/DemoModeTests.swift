import Foundation
import Testing

@testable import TokenBarCore

struct DemoModeTests {
    @Test func isOffWithoutTheFlag() {
        #expect(!DemoMode.isRequested(in: [:]))
        #expect(!DemoMode.isRequested(in: ["DEBUG": "1"]))
    }

    @Test func isOnOnlyForExplicitOne() {
        #expect(DemoMode.isRequested(in: ["TOKENBAR_DEMO": "1"]))
        #expect(!DemoMode.isRequested(in: ["TOKENBAR_DEMO": "0"]))
        #expect(!DemoMode.isRequested(in: ["TOKENBAR_DEMO": ""]))
    }

    /// ⌘R must run the real providers: the shared scheme may list the demo flag, but never enabled.
    @Test func sharedSchemeDoesNotEnableDemoMode() throws {
        let scheme = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "../../../TokenBar.xcodeproj/xcshareddata/xcschemes/TokenBar.xcscheme")
            .standardized
        let xml = try XMLDocument(contentsOf: scheme)
        let launchVariables = try xml.nodes(forXPath: "//LaunchAction//EnvironmentVariable[@isEnabled='YES']/@key")
        let launchArguments = try xml.nodes(forXPath: "//LaunchAction//CommandLineArgument[@isEnabled='YES']/@argument")

        #expect(!launchVariables.contains { $0.stringValue == DemoMode.environmentKey })
        #expect(!launchArguments.contains { $0.stringValue?.contains("Mock") == true })
    }
}
