import Foundation
import os

@testable import TokenBarCore

/// A clock tests can move forward.
final class TestClock: Sendable {
    private let current: OSAllocatedUnfairLock<Date>

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        current = OSAllocatedUnfairLock(initialState: start)
    }

    var now: Date { current.withLock { $0 } }

    func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }
}

/// Provider whose results are scripted per call and which counts how often it is called.
final class StubProvider: UsageProvider {
    let descriptor: ProviderDescriptor
    private let results: OSAllocatedUnfairLock<[Result<[UsageLimit], ProviderError>]>
    private let calls = OSAllocatedUnfairLock(initialState: 0)
    private let clock: TestClock
    private let latency: Duration

    init(
        id: ProviderID = "stub",
        clock: TestClock,
        latency: Duration = .zero,
        results: [Result<[UsageLimit], ProviderError>]
    ) {
        self.descriptor = ProviderDescriptor(id: id, displayName: "Stub")
        self.clock = clock
        self.latency = latency
        self.results = OSAllocatedUnfairLock(initialState: results)
    }

    var callCount: Int { calls.withLock { $0 } }

    func fetchUsage() async throws -> UsageSnapshot {
        calls.withLock { $0 += 1 }
        if latency > .zero { try await Task.sleep(for: latency) }
        let result = results.withLock { $0.count > 1 ? $0.removeFirst() : $0[0] }
        let limits = try result.get()
        return UsageSnapshot(provider: descriptor.id, plan: "Pro", limits: limits, fetchedAt: clock.now)
    }
}

extension UsageLimit {
    static func session(_ used: Double) -> UsageLimit {
        UsageLimit(id: "session", window: .session, usedFraction: used, resetsAt: nil)
    }
}
