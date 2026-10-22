import ServiceManagement
import Testing

@testable import TokenBarUI

@MainActor
struct LaunchAtLoginTests {
    final class FakeService: LoginItemService {
        var status: SMAppService.Status = .notRegistered
        var statusAfterRegister: SMAppService.Status = .enabled
        var failure: (any Error)?

        func register() throws {
            if let failure { throw failure }
            status = statusAfterRegister
        }

        func unregister() throws {
            if let failure { throw failure }
            status = .notRegistered
        }
    }

    struct Failure: Error {}

    @Test func readsInitialStatusFromService() {
        let service = FakeService()
        service.status = .enabled
        #expect(LaunchAtLogin(service: service).isEnabled)
    }

    @Test func registersAndUnregisters() {
        let service = FakeService()
        let login = LaunchAtLogin(service: service)

        login.setEnabled(true)
        #expect(login.isEnabled)
        #expect(!login.requiresApproval)

        login.setEnabled(false)
        #expect(!login.isEnabled)
    }

    @Test func reportsPendingApprovalAsEnabled() {
        let service = FakeService()
        service.statusAfterRegister = .requiresApproval
        let login = LaunchAtLogin(service: service)

        login.setEnabled(true)

        #expect(login.isEnabled)
        #expect(login.requiresApproval)
    }

    @Test func keepsSystemStateWhenChangeFails() {
        let service = FakeService()
        service.failure = Failure()
        let login = LaunchAtLogin(service: service)

        login.setEnabled(true)

        #expect(!login.isEnabled)
        #expect(login.lastChangeFailed)
    }

    @Test func picksUpChangesMadeInSystemSettings() {
        let service = FakeService()
        let login = LaunchAtLogin(service: service)

        service.status = .enabled
        login.refresh()

        #expect(login.isEnabled)
    }
}
