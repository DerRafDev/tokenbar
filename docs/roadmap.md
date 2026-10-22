# Roadmap

Each milestone ends with green CI and updated docs. Real providers come **after**
settings, because connecting and disconnecting a provider is part of shipping it.

| # | Milestone | Exit criteria |
|---|---|---|
| 0 | **Repository foundation** | Community files, `swift format` config, CI workflow, Dependabot, PR/issue templates, provider research ([providers.md](providers.md)). |
| 1 | **Native macOS shell** | Xcode project + `TokenBarKit` package. Menu-bar-only app (`LSUIElement`), `MenuBarExtra` window, empty Settings scene. Builds in CI. |
| 2 | **Usage domain + mocks + refresh** | `UsageProvider`, `UsageSnapshot`, `UsageLimit`, `UsageStore`, refresh scheduling, staleness, reset formatting. Debug-only mock providers. Unit tests for the edge cases (0%, 100%, nil, expired reset, time zones, stale, partial data, errors). |
| 3 | **UI matching the mockup** | Menu bar label `S 17% \| W 79%`, popover sections, progress bars, reset text, stale/error/disconnected states, footer. English + Portuguese (Brazil). |
| 4 | **Settings + Keychain + launch at login** | General (launch at login, refresh interval, show in menu bar) and Providers (status, show in menu bar, connect/disconnect). `CredentialStore`. |
| 5 | **Claude provider** | Policy decision recorded. Sanitized fixtures. Parser + error-mapping tests. Behind the provider registry. |
| 6 | **ChatGPT provider** | Same as above. Naming decision recorded (ChatGPT vs Codex). |
| 7 | **Release pipeline** | Tag-triggered workflow: test → archive → sign → notarize → DMG/zip → checksum → GitHub Release. Signing steps skip cleanly when secrets are absent. |
| 8 | **Docs + 0.1.0** | README screenshot, `adding-a-provider.md` verified by following it, first public release. |

## Not planned (yet)

Windows/Linux apps, CLI, website, widgets, notifications, usage history. The
boundaries in [architecture.md](architecture.md) keep these possible without
building them now.
