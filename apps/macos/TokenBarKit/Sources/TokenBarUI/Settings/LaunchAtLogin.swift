import Observation
import ServiceManagement
import TokenBarCore
import os

/// The part of `SMAppService` that ``LaunchAtLogin`` uses, so tests can replace it.
@MainActor
public protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Whether TokenBar opens at login, backed by `SMAppService.mainApp`.
///
/// The system owns this setting: the user can also change it in System Settings › General ›
/// Login Items, so the state is read from the service instead of being stored by TokenBar.
@MainActor
@Observable
public final class LaunchAtLogin {
    public private(set) var status: SMAppService.Status
    /// Set when the last change failed. Cleared by the next successful change.
    public private(set) var lastChangeFailed = false

    @ObservationIgnored private let service: any LoginItemService
    @ObservationIgnored private let logger = Logger(subsystem: Log.subsystem, category: "login-item")

    public init(service: any LoginItemService = SMAppService.mainApp) {
        self.service = service
        self.status = service.status
    }

    /// True when TokenBar is registered, including while it waits for the user's approval.
    public var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    /// True when macOS needs the user to allow TokenBar in Login Items before it can open at login.
    public var requiresApproval: Bool {
        status == .requiresApproval
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try service.register() } else { try service.unregister() }
            lastChangeFailed = false
        } catch {
            lastChangeFailed = true
            logger.error("Login item change failed: \(String(describing: error), privacy: .public)")
        }
        refresh()
    }

    /// Re-reads the status, for example when the Settings window appears.
    public func refresh() {
        status = service.status
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
