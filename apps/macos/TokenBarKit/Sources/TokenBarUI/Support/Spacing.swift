import CoreGraphics

/// The few spacing steps the UI uses, so vertical rhythm stays consistent.
enum Spacing {
    /// Between a label and the line that belongs to it (title → bar, bar → reset time).
    static let tight: CGFloat = 6
    /// Between related items in a row, such as an icon and its name.
    static let small: CGFloat = 8
    /// Between limits of one provider, and between a header and its content.
    static let medium: CGFloat = 14
    /// Popover edge insets and the space around dividers between providers.
    static let large: CGFloat = 16
}
