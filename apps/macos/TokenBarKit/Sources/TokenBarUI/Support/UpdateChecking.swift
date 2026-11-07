/// Checks for a newer TokenBar on request. The app implements it with Sparkle, which owns the
/// update dialogs (found, downloading, install and relaunch, up to date, errors).
///
/// Lives here so the popover can offer *Check for Updates…* without depending on Sparkle.
@MainActor
public protocol UpdateChecking: AnyObject {
    /// False while a check or an update is already in progress.
    var canCheckForUpdates: Bool { get }
    /// Starts a user-initiated check and shows its result.
    func checkForUpdates()
}
