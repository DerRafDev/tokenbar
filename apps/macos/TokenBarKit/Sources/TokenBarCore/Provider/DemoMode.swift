/// Decides whether the app runs demo providers instead of the real ones.
///
/// Demo mode is never implied by the build configuration: a Debug build runs the real
/// providers unless the launch environment sets `TOKENBAR_DEMO=1`. Release builds have no
/// mock providers, so the app ignores the flag there.
public enum DemoMode {
    public static let environmentKey = "TOKENBAR_DEMO"

    public static func isRequested(in environment: [String: String]) -> Bool {
        environment[environmentKey] == "1"
    }
}
