import Foundation

extension Bundle {
    /// This module's resource bundle, reachable from tests (which have no `Bundle.module` of their own).
    static var tokenBarUI: Bundle { .module }
}
