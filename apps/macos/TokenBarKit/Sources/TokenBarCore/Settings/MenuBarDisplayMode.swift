/// How much the menu bar shows when usage is on.
///
/// The raw value is persisted in user settings, so it must never change once shipped.
public enum MenuBarDisplayMode: String, CaseIterable, Sendable {
    /// Each provider's icon and its highest usage. Falls back to ``minimal`` when it gets too wide.
    case providers
    /// Only the provider closest to its limit.
    case minimal
    /// Each provider's icon and its two main limits, such as "15/12".
    case detailed
}
