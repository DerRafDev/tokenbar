import Observation

extension UsageStore {
    /// Applies the enabled providers and refresh interval from `settings` now and whenever they change.
    ///
    /// Settings stay the single source of truth: the Settings window edits ``AppSettings`` only,
    /// and the store follows.
    public func follow(_ settings: AppSettings) {
        let (enabled, interval) = withObservationTracking {
            (settings.enabledProviders, settings.refreshInterval)
        } onChange: { [weak self, weak settings] in
            Task { @MainActor in
                guard let self, let settings else { return }
                self.follow(settings)
            }
        }
        if enabledProviders != enabled { enabledProviders = enabled }
        if policy.interval != interval { policy.interval = interval }
    }
}
