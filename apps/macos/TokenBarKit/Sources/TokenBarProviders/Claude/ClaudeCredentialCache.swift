import Foundation
import TokenBarCore
import os

/// Keeps Claude Code's sign-in in memory so the Keychain item, and the macOS permission prompt that
/// can come with it, is not read on every refresh.
///
/// The item's data is read again only when:
/// - nothing usable is cached and no read happened yet,
/// - Claude Code wrote the item since the last read (its modification date changed), or
/// - the cached token expired or was rejected, at most once per ``retryInterval``, in case Claude
///   Code renewed it without the modification date changing.
///
/// Memory only: nothing is written to disk, `UserDefaults`, or another Keychain item, and everything
/// is gone when TokenBar quits. Being an actor, reads are serialized: concurrent refreshes share one
/// Keychain read, and an invalidation can never be undone by an older read finishing later.
actor ClaudeCredentialCache {
    /// A token this close to `expiresAt` is treated as expired, so it does not expire mid-request.
    static let expiryMargin: TimeInterval = 60
    /// Minimum time between reads while the item has not changed. Bounds how often macOS can ask.
    static let retryInterval: TimeInterval = 15 * 60

    private let source: any ClaudeCredentialSource
    private let now: @Sendable () -> Date
    private let logger = Logger(subsystem: Log.subsystem, category: "claude")

    private var cached: ClaudeCodeCredentials?
    /// The item's modification date when it was last read.
    private var readVersion: Date?
    /// When the item was last read, or its token last rejected. Starts the ``retryInterval``.
    private var lastAttempt: Date?
    /// Why the cached sign-in cannot be used, reported until the next read.
    private var failure: ProviderError?
    /// Token the endpoint rejected. Never sent again, even if the Keychain returns it again.
    private var rejectedToken: String?

    init(source: any ClaudeCredentialSource, now: @escaping @Sendable () -> Date) {
        self.source = source
        self.now = now
    }

    /// A sign-in that is not expired and was not rejected, from memory when possible.
    func credentials() throws -> ClaudeCodeCredentials {
        let version: Date?
        do {
            version = try source.modificationDate()
        } catch {
            // Claude Code signed out: forget the old sign-in instead of sending it.
            clear()
            throw error
        }

        if let cached, isUsable(cached), version == nil || version == readVersion {
            logger.debug("Reusing Claude Code sign-in from memory")
            return cached
        }

        let changed = version != nil && version != readVersion
        if !changed, let lastAttempt, now().timeIntervalSince(lastAttempt) < Self.retryInterval {
            // The Keychain would most likely return the same sign-in; do not ask macOS again yet.
            throw failure ?? .unauthorized
        }
        return try read(version: version)
    }

    /// Marks `accessToken` as rejected by the endpoint. Ignored if a newer token is cached.
    func reject(_ accessToken: String) {
        guard cached?.accessToken == accessToken else { return }
        rejectedToken = accessToken
        failure = .unauthorized
        lastAttempt = now()
    }

    private func read(version: Date?) throws -> ClaudeCodeCredentials {
        logger.debug("Reading Claude Code sign-in from the Keychain")
        lastAttempt = now()
        readVersion = version
        let credentials: ClaudeCodeCredentials
        do {
            credentials = try source.credentials()
        } catch ProviderError.accessDenied {
            // The user declined. Only a manual refresh asks again (see `ProviderState.shouldRefresh`),
            // and it must not be held back by the retry interval.
            clear()
            throw ProviderError.accessDenied
        } catch {
            cached = nil
            failure = ProviderError(error)
            throw error
        }

        cached = credentials
        guard isUsable(credentials) else {
            logger.info("Claude Code sign-in expired or rejected; not calling the endpoint")
            failure = .unauthorized
            throw ProviderError.unauthorized
        }
        failure = nil
        rejectedToken = nil
        return credentials
    }

    private func isUsable(_ credentials: ClaudeCodeCredentials) -> Bool {
        credentials.accessToken != rejectedToken
            && !credentials.isExpired(at: now().addingTimeInterval(Self.expiryMargin))
    }

    private func clear() {
        cached = nil
        readVersion = nil
        lastAttempt = nil
        failure = nil
        rejectedToken = nil
    }
}
