import AppKit
import Observation
import Sparkle
import TokenBarUI

/// In-app updates with Sparkle's standard dialogs. Checks only when the user asks
/// (`SUEnableAutomaticChecks` is off in Config/Info.plist). The feed and the public EdDSA key
/// come from build settings; see docs/releasing.md.
@MainActor
@Observable
final class SoftwareUpdater: UpdateChecking {
    private(set) var canCheckForUpdates = false

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        canCheckForUpdates = controller.updater.canCheckForUpdates
        // Sparkle changes this on the main thread.
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, change in
            guard let canCheck = change.newValue else { return }
            MainActor.assumeIsolated { self?.canCheckForUpdates = canCheck }
        }
    }

    func checkForUpdates() {
        // TokenBar has no Dock icon, so bring it forward or Sparkle's window opens behind others.
        NSApp.activate()
        controller.checkForUpdates(nil)
    }
}
