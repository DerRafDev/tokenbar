import Foundation
import Testing

@testable import TokenBarCore

@MainActor
struct AgentActivityStoreTests {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let session = AgentSessionKey(provider: "claude", sessionID: "session-1")

    private func event(_ kind: AgentEvent.Kind, _ key: AgentSessionKey? = nil, after seconds: TimeInterval = 0)
        -> AgentEvent
    {
        AgentEvent(key: key ?? session, kind: kind, project: "tokenbar", date: start.addingTimeInterval(seconds))
    }

    @Test func questionMakesSessionPending() {
        let store = AgentActivityStore()
        store.apply(event(.waiting(.answer)))
        #expect(store.pendingCount == 1)
        #expect(store.pending.first?.project == "tokenbar")
        #expect(store.pending.first?.reason == .answer)
    }

    @Test func repeatedQuestionCountsOnceAndKeepsStartTime() {
        let store = AgentActivityStore()
        store.apply(event(.waiting(.answer)))
        store.apply(event(.waiting(.answer), after: 30))
        #expect(store.pendingCount == 1)
        #expect(store.pending.first?.since == start)
    }

    @Test func resolvedQuestionDoesNotComeBackOnRepeatedResolve() {
        let store = AgentActivityStore()
        store.apply(event(.waiting(.answer)))
        store.apply(event(.resolved, after: 5))
        store.apply(event(.resolved, after: 6))
        #expect(store.pendingCount == 0)
    }

    @Test func newQuestionAfterResolveIsPendingAgain() {
        let store = AgentActivityStore()
        store.apply(event(.waiting(.answer)))
        store.apply(event(.resolved, after: 5))
        store.apply(event(.waiting(.answer), after: 60))
        #expect(store.pending.first?.since == start.addingTimeInterval(60))
    }

    @Test func endedSessionIsRemoved() {
        let store = AgentActivityStore()
        store.apply(event(.waiting(.answer)))
        store.apply(event(.ended, after: 1))
        #expect(store.pendingCount == 0)
    }

    @Test func sameSessionIDFromTwoProvidersCountsTwice() {
        let store = AgentActivityStore()
        store.apply(event(.waiting(.answer)))
        store.apply(event(.waiting(.answer), AgentSessionKey(provider: "codex", sessionID: "session-1")))
        #expect(store.pendingCount == 2)
    }

    @Test func resolvingOneSessionKeepsTheOther() {
        let store = AgentActivityStore()
        let other = AgentSessionKey(provider: "claude", sessionID: "session-2")
        store.apply(event(.waiting(.answer)))
        store.apply(event(.waiting(.answer), other, after: 10))
        store.apply(event(.resolved, after: 20))
        #expect(store.pending.map(\.key) == [other])
    }

    @Test func pendingIsLongestWaitingFirst() {
        let store = AgentActivityStore()
        let other = AgentSessionKey(provider: "claude", sessionID: "session-2")
        store.apply(event(.waiting(.answer), other, after: 10))
        store.apply(event(.waiting(.answer)))
        #expect(store.pending.map(\.key) == [session, other])
    }

    @Test func dismissRemovesUntilNextQuestion() {
        let store = AgentActivityStore()
        store.apply(event(.waiting(.answer)))
        store.dismiss(session)
        #expect(store.pendingCount == 0)
        store.apply(event(.waiting(.answer), after: 30))
        #expect(store.pendingCount == 1)
    }

    @Test func removeAllForProviderKeepsOthers() {
        let store = AgentActivityStore()
        let codex = AgentSessionKey(provider: "codex", sessionID: "x")
        store.apply(event(.waiting(.answer)))
        store.apply(event(.waiting(.answer), codex))
        store.removeAll(provider: "claude")
        #expect(store.pending.map(\.key) == [codex])
    }
}
