/// Shared logging configuration.
///
/// Use `os.Logger` with this subsystem. Interpolated values are private by default;
/// mark only non-sensitive values (provider IDs, error cases, counts) as `.public`.
/// Never log tokens, cookies, account IDs, URLs with credentials, or response bodies.
public enum Log {
    public static let subsystem = "io.github.derrafdev.TokenBar"
}
