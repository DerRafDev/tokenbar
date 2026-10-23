# Roadmap

## 0.1.0 (first public release)

Done: native menu bar app, experimental Claude and Codex providers, session and weekly
limits with reset countdowns, menu bar display modes, automatic refresh, launch at login,
English and Portuguese (Brazil), release pipeline (DMG, ZIP, checksums; signing and
notarization ready but unused). 0.1.0 ships unsigned and not notarized.

Milestones 0–8 took it from an empty repository to this release; the history is in the
merged pull requests.

## After 0.1.0

Candidates, not commitments. Each needs evidence that it works reliably before it is built.

| Item | Status |
|---|---|
| **Developer ID signing and notarization** | Needs an Apple Developer Program membership. The release pipeline already supports it ([releasing.md](releasing.md)). Removes the Gatekeeper override and keeps Claude's Keychain permission across updates. |
| **Codex Keychain sign-in** (`cli_auth_credentials_store = "keyring"`) | Needs a verified capture of the item's format. Until then those installations show "Not connected". |
| **Codex 403 vs. workspace without Codex** | Needs a captured 403 response that tells the two apart. Both show "Sign-in expired" today. |
| **Refresh when the network comes back** | Today data stays marked outdated until the next scheduled refresh after an outage. |
| **Automatic updates** | Would add the first network request not made for a provider. Needs a privacy-preserving design. |
| **More providers** (Gemini, Cursor, Copilot, …) | Only with a reliable, documented-enough source. Start with a section in [providers.md](providers.md). |
| **Menu bar customization** | Driven by dogfooding feedback. |

## Not planned

Windows/Linux apps, CLI, website, widgets, notifications, usage history, cloud sync,
accounts. The boundaries in [architecture.md](architecture.md) keep some of these possible
without building them now.
