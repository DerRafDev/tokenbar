# Architecture

TokenBar is a menu-bar-only macOS app. It is small on purpose. This document explains
the few boundaries that exist and why each one does.

## Repository layout

```text
tokenbar/
├── apps/
│   └── macos/                     # The macOS app (the only app today)
│       ├── TokenBar.xcodeproj     # Thin app target: entry point, Info.plist, signing
│       ├── TokenBar/              # App sources (composition root only)
│       └── TokenBarKit/           # Swift package with all logic and all tests
├── docs/                          # Architecture, providers, releasing, roadmap
├── scripts/                       # Shell scripts used by developers and CI
└── .github/                       # CI, release workflow, templates
```

Future apps (`apps/cli`, `apps/website`, …) are added as siblings. Code is only moved
to `packages/` when a **second consumer actually exists**. Until then a top-level
`packages/` folder would be empty ceremony.

### Why an Xcode project *and* a Swift package

- A menu bar app needs a real `.app` bundle (`LSUIElement`, code signing, hardened
  runtime, `SMAppService` for launch-at-login). SwiftPM cannot produce one on its own,
  so a thin Xcode project builds the bundle.
- Everything else lives in `TokenBarKit`, a local Swift package. It builds and tests
  with plain `swift build` / `swift test`, gives fast CI, and keeps review diffs out
  of `project.pbxproj`.
- The Xcode project uses **folder-synchronized groups**. Adding a source file to
  `TokenBar/` does not touch `project.pbxproj`, so the file rarely changes or conflicts.
  No project generator (XcodeGen/Tuist) is needed.

## Modules

```text
            ┌──────────────┐
            │ TokenBar.app │  composition root: builds providers, store, scenes
            └──────┬───────┘
          ┌────────┴─────────┐
          ▼                  ▼
   ┌─────────────┐   ┌──────────────────┐
   │ TokenBarUI  │   │ TokenBarProviders│  Claude, Codex, HTTP, credentials
   └──────┬──────┘   └────────┬─────────┘
          └────────┬──────────┘
                   ▼
            ┌──────────────┐
            │ TokenBarCore │  domain model, UsageProvider protocol, refresh, formatting
            └──────────────┘
```

| Module | Knows about | Must not know about |
|---|---|---|
| `TokenBarCore` | Usage domain, refresh policy, time | SwiftUI, URLs, tokens |
| `TokenBarProviders` | Endpoints, auth, response formats | SwiftUI |
| `TokenBarUI` | Views, presentation | Endpoints, auth, any concrete provider |
| App target | Wiring | Business logic |

The `TokenBarUI ↛ TokenBarProviders` rule is enforced by the compiler: the UI module
does not depend on the providers module. (`TokenBarProviders` holds the Keychain
`CredentialStore` today; real providers join it from Milestone 5. The debug-only
`MockUsageProvider` lives in `TokenBarCore`, so SwiftUI previews can use it.)

Provider-specific presentation (name, SF Symbol, demo flag) comes from
`ProviderDescriptor`, so the UI never switches on provider IDs.

## Domain model

```swift
public protocol UsageProvider: Sendable {
    var descriptor: ProviderDescriptor { get }   // id, display name
    func fetchUsage() async throws -> UsageSnapshot
}

public struct UsageSnapshot {
    let provider: ProviderID
    let plan: String?              // "Pro", "Plus" — when the provider reports it
    let limits: [UsageLimit]       // zero or more, in display order
    let fetchedAt: Date
}

public struct UsageLimit {
    let id: String                 // stable per provider: "session", "weekly", "weekly.opus"
    let window: LimitWindow        // .session, .rolling(length:), .daily, .weekly, .monthly
    let scope: String?             // model name for model-specific limits
    let usedFraction: Double?      // 0…1; nil when the provider gives no percentage
    let resetsAt: Date?            // absolute; nil when unknown
}
```

Why a **list of limits** instead of fixed `sessionUsage` / `weeklyUsage` fields:
providers differ (5-hour session, rolling 5-hour window, weekly, model-specific weekly,
daily, monthly), and a fixed struct would grow an optional field per provider. A list
with a small `LimitWindow` enum covers all known cases and stays readable.

**A metric is never relabeled to make providers look consistent.** Each limit is the
window the provider actually reports: a Claude session (starts with the first message)
is `.session`; a window counting the trailing 5 hours is `.rolling(length: 5h)`, even
though both last five hours. The menu bar shows every unscoped limit in provider order
with a compact label (`S 17% | W 79%`, `5h 12% | W 42%`); the popover spells it out
("Current session", "Rolling window (5 hours)").

`usedFraction` is optional because "no percentage available" is different from "0%".
The UI never renders a missing value as an empty bar.

## Refresh

`UsageStore` (main actor, `@Observable`) owns one state per provider:

```text
ProviderState = connection + last good snapshot + last error + isRefreshing
```

- One timer for all providers (default 5 min, configurable), with a tolerance so
  macOS can coalesce wakeups.
- A refresh already in flight is never started again (per provider).
- A failed refresh **keeps the last good snapshot** and marks it stale. The UI shows
  the data plus an "Updated 12 min ago" warning instead of an error screen.
- Rate limits (HTTP 429) back off using `Retry-After` when present.
- Opening the popover triggers a refresh only if data is older than the stale threshold.
- Countdowns ("in 2h 50min") are computed locally from `resetsAt` and re-rendered
  with `TimelineView(.everyMinute)` only while the popover is open. No network
  request is made to update a countdown.
- The scheduler sleeps on the continuous clock, so after the Mac wakes from sleep the
  overdue refresh runs right away without a separate wake observer.
- The menu bar label is rendered into a template image (MenuBarExtra drops symbols
  embedded in text), only when its values change.

## Mock data

Debug builds can run with demo providers: the shared scheme passes
`-TokenBarUseMocks YES`. Mock code is wrapped in `#if DEBUG` and absent from Release
builds, and the popover labels demo data with a "Demo" badge.

## Security boundaries

- Third-party credentials (Claude Code, Codex) are **read at fetch time** and never
  copied, refreshed, or persisted by TokenBar.
- Credentials TokenBar owns go through `CredentialStore`: generic password items in
  the login Keychain, scoped to TokenBar's service, `AfterFirstUnlockThisDeviceOnly`,
  never synced to iCloud. Nothing sensitive goes in `UserDefaults`, files, or logs.
- Logging uses `os.Logger` with privacy annotations. Tokens, cookies, account IDs,
  authenticated URLs, and response bodies are never logged.
- No TokenBar backend. The app talks only to provider endpoints.
  *Usage data stays on your Mac.*

## Dependencies

None. Foundation, SwiftUI, AppKit, Security, ServiceManagement, and OSLog cover
networking, JSON, Keychain, dates, and UI. Lint and formatting use `swift format`,
which ships with Xcode.
