import Foundation
import Testing

@testable import TokenBarCore

/// Simulates the system: installed apps, running processes, and Terminal tabs.
@MainActor
final class FakeNavigationEnvironment: AgentNavigationEnvironment {
    var apps = ["com.apple.Terminal": "Terminal", "com.microsoft.VSCode": "Visual Studio Code"]
    var exactTargetApps: Set<String> = ["com.apple.Terminal"]
    /// Running processes and the TTY each owns.
    var processes: [AgentProcess: String] = [:]
    /// TTYs of open Terminal tabs.
    var tabs: Set<String> = []
    private(set) var shownTabs: [String] = []
    private(set) var activatedApps: [String] = []

    func appName(bundleID: String) -> String? { apps[bundleID] }

    func supportsExactTarget(_ target: AgentOrigin.Target, bundleID: String) -> Bool {
        exactTargetApps.contains(bundleID)
    }

    func isRunning(_ process: AgentProcess, tty: String) -> Bool { processes[process] == tty }

    func showTerminalTab(tty: String, bundleID: String) -> Bool {
        guard tabs.contains(tty) else { return false }
        shownTabs.append(tty)
        return true
    }

    func activateApp(bundleID: String) -> Bool {
        activatedApps.append(bundleID)
        return true
    }
}

@MainActor
struct AgentSessionNavigatorTests {
    let environment = FakeNavigationEnvironment()
    let processA = AgentProcess(id: 100, startedAt: Date(timeIntervalSince1970: 1_000))
    let processB = AgentProcess(id: 200, startedAt: Date(timeIntervalSince1970: 2_000))

    private func terminal(_ tty: String, _ process: AgentProcess) -> AgentOrigin {
        AgentOrigin(appBundleID: "com.apple.Terminal", target: .terminalTab(tty: tty, process: process))
    }

    private var navigator: AgentSessionNavigator { AgentSessionNavigator(environment: environment) }

    @Test func liveTerminalTabOffersGoToSession() {
        environment.processes = [processA: "ttys005"]
        environment.tabs = ["ttys005"]
        #expect(navigator.action(for: terminal("ttys005", processA)) == .goToSession)
        #expect(navigator.appName(for: terminal("ttys005", processA)) == "Terminal")
    }

    @Test func goToSessionShowsTheRightTabAmongTwoInTheSameFolder() {
        environment.processes = [processA: "ttys005", processB: "ttys007"]
        environment.tabs = ["ttys005", "ttys007"]
        let navigator = navigator
        #expect(navigator.open(terminal("ttys007", processB)) == .openedSession)
        #expect(navigator.open(terminal("ttys005", processA)) == .openedSession)
        #expect(environment.shownTabs == ["ttys007", "ttys005"])
        #expect(environment.activatedApps.isEmpty)
    }

    @Test func appOnlyOriginOffersOpenApp() {
        let origin = AgentOrigin(appBundleID: "com.microsoft.VSCode")
        #expect(navigator.action(for: origin) == .openApp(name: "Visual Studio Code"))
        #expect(navigator.open(origin) == .openedApp)
        #expect(environment.activatedApps == ["com.microsoft.VSCode"])
    }

    @Test func unknownOrUninstalledAppOffersNothing() {
        #expect(navigator.action(for: nil) == nil)
        #expect(navigator.action(for: AgentOrigin(appBundleID: nil)) == nil)
        #expect(navigator.action(for: AgentOrigin(appBundleID: "com.example.Missing")) == nil)
        #expect(navigator.open(AgentOrigin(appBundleID: "com.example.Missing")) == .failed)
    }

    @Test func exactTargetInAnAppWithoutSupportOffersOpenApp() {
        environment.processes = [processA: "ttys005"]
        let origin = AgentOrigin(
            appBundleID: "com.microsoft.VSCode", target: .terminalTab(tty: "ttys005", process: processA))
        #expect(navigator.action(for: origin) == .openApp(name: "Visual Studio Code"))
    }

    /// A closed session falls back to its app in the label, and a click never lands on a tab that
    /// reuses its TTY.
    @Test func closedSessionIsNotOpenedEvenIfItsTTYWasReused() {
        environment.tabs = ["ttys005"]
        environment.processes = [processB: "ttys005"]  // A new tab reused the TTY.
        let origin = terminal("ttys005", processA)
        #expect(navigator.action(for: origin) == .openApp(name: "Terminal"))
        #expect(navigator.open(origin) == .sessionClosed)
        #expect(environment.shownTabs.isEmpty)
        #expect(environment.activatedApps.isEmpty)
    }

    @Test func sessionClosedBetweenDrawingAndClickIsCaught() {
        environment.processes = [processA: "ttys005"]
        environment.tabs = ["ttys005"]
        let origin = terminal("ttys005", processA)
        let navigator = navigator
        #expect(navigator.action(for: origin) == .goToSession)
        environment.processes = [:]
        environment.tabs = []
        #expect(navigator.open(origin) == .sessionClosed)
        #expect(environment.shownTabs.isEmpty)
    }

    /// Inside tmux the process lives but owns no Terminal tab: the app is the closest certain place.
    @Test func liveProcessWithoutTabOpensTheApp() {
        environment.processes = [processA: "ttys009"]
        environment.tabs = ["ttys005"]
        #expect(navigator.open(terminal("ttys009", processA)) == .openedApp)
        #expect(environment.activatedApps == ["com.apple.Terminal"])
    }

    @Test func storeKeepsTheOriginOfTheWaitingEvent() {
        let store = AgentActivityStore()
        let key = AgentSessionKey(provider: "claude", sessionID: "s")
        let origin = terminal("ttys005", processA)
        store.apply(AgentEvent(key: key, kind: .waiting(.answer), project: "p", origin: origin, date: .now))
        #expect(store.pending.first?.origin == origin)
    }
}
