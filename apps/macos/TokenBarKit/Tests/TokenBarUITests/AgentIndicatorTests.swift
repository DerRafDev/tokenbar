import Foundation
import Testing
import TokenBarCore

@testable import TokenBarUI

struct AgentIndicatorTests {
    let names: [ProviderID: String] = ["claude": "Claude", "codex": "Codex"]

    private func pending(_ provider: ProviderID, _ id: String) -> PendingAgentSession {
        PendingAgentSession(
            key: AgentSessionKey(provider: provider, sessionID: id),
            reason: .answer,
            agentName: nil,
            project: nil,
            since: Date(timeIntervalSince1970: 0)
        )
    }

    @Test func showsNothingWhileNothingWaits() {
        #expect(AgentIndicator.label(for: [], names: names, compact: false) == nil)
    }

    @Test func namesTheProviderWhenOnlyOneIsWaiting() {
        let label = AgentIndicator.label(
            for: [pending("claude", "a"), pending("claude", "b")], names: names, compact: false)
        #expect(label?.text == "Claude · 2")
        #expect(label?.spoken == "Claude: 2 questions waiting for an answer")
    }

    @Test func singleQuestionIsSpokenInSingular() {
        let label = AgentIndicator.label(for: [pending("claude", "a")], names: names, compact: false)
        #expect(label?.text == "Claude · 1")
        #expect(label?.spoken == "Claude: 1 question waiting for an answer")
    }

    @Test func compactShowsOnlyTheCount() {
        let label = AgentIndicator.label(
            for: [pending("claude", "a"), pending("claude", "b")], names: names, compact: true)
        #expect(label?.text == "2")
        #expect(label?.spoken == "2 questions waiting for an answer")
    }

    @Test func severalProvidersShowOnlyTheCount() {
        let label = AgentIndicator.label(
            for: [pending("claude", "a"), pending("codex", "b")], names: names, compact: false)
        #expect(label?.text == "2")
    }

    @Test func popoverOpensOnAgentsOnlyWhileSomethingWaits() {
        #expect(PopoverTab.initial(pendingCount: 0) == .usage)
        #expect(PopoverTab.initial(pendingCount: 1) == .agents)
    }
}
