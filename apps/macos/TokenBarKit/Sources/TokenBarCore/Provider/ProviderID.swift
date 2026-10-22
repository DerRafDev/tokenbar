/// Stable identifier of a usage provider, such as `claude` or `chatgpt`.
///
/// The raw value is persisted in user settings, so it must never change once shipped.
public struct ProviderID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension ProviderID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

extension ProviderID: CustomStringConvertible {
    public var description: String { rawValue }
}
