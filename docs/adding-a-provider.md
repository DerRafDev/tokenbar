# Adding a provider

A provider is one type that conforms to `UsageProvider` and returns a normalized
`UsageSnapshot`. Adding one should not require changes to the UI or the refresh logic.

> **Status:** the provider module (`TokenBarProviders`) arrives with the first real
> provider (Milestone 5). Steps 3 and 6 will be finalized then; the rest is stable.

## 1. Document the data source first

Add a section to [providers.md](providers.md) with: authentication method, usage source,
available metrics, reset information, known limitations, and security considerations.
Open a PR or issue with just this section if the source is unofficial. We would rather
agree on the source before reviewing code.

Do not invent endpoints or fields. If something cannot be obtained reliably, say so.

## 2. Implement `UsageProvider`

```swift
import TokenBarCore

public struct GeminiProvider: UsageProvider {
    public let descriptor = ProviderDescriptor(
        id: "gemini",                 // persisted in settings, never change it
        displayName: "Gemini",
        symbolName: "sparkle"         // neutral SF Symbol, not a company logo
    )

    public func fetchUsage() async throws -> UsageSnapshot {
        // 1. Read credentials (throw ProviderError.notConnected if missing).
        // 2. Request usage (map HTTP status with ProviderError(httpStatus:retryAfter:)).
        // 3. Decode, then map into UsageLimit values.
        UsageSnapshot(provider: descriptor.id, plan: plan, limits: limits, fetchedAt: Date())
    }
}
```

Mapping rules:

- Use **absolute** reset dates (`resetsAt`). Convert relative values ("resets in 3600 s")
  against the response time, never by parsing display strings.
- Use `usedPercent:` for 0–100 values or `usedFraction:` for 0–1. Pass `nil` when the
  provider gives no percentage. Never substitute `0`.
- Pick the `LimitWindow` by the window's real length, not by field position. Use `scope`
  for model-specific limits (`scope: "Opus"`, `id: "weekly.opus"`).
- Return the limits you have. Partial data is fine.
- Throw `ProviderError`. Its cases carry no text on purpose: never put response bodies
  in errors.

## 3. Credentials

- Credentials owned by another app (a CLI login, for example): read them at fetch time.
  Never copy, refresh, or log them.
- Credentials TokenBar stores: use `CredentialStore` (Keychain). Never `UserDefaults` or files.

## 4. Logging

Use `Logger(subsystem: Log.subsystem, category: "<provider id>")`. Only provider IDs,
status codes, and counts may be `.public`. See [SECURITY.md](../SECURITY.md).

## 5. Tests and fixtures

- Capture one real response locally, sanitize it (remove tokens, IDs, emails, and fix
  timestamps), and save it under the provider's test folder as `<name>.json`.
- Test parsing, mapping to `UsageLimit`, and each error path (401, 429 with and
  without `Retry-After`, invalid JSON, missing fields).
- Inject the HTTP layer so tests never touch the network.

## 6. Register it

Add the provider to `ProviderRegistry` in `apps/macos/TokenBar/ProviderRegistry.swift`.
That is the only app-level change.

## 7. Open the PR

Title: `feat(provider): add Gemini support`. Include the providers.md section and a
screenshot of the popover.
