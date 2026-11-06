# Roadmap

## 0.1.0 (first public release)

Done: native menu bar app, experimental Claude and Codex providers, session and weekly
limits with reset countdowns, menu bar display modes, automatic refresh, launch at login,
English and Portuguese (Brazil), release pipeline (DMG, ZIP, checksums; signing and
notarization ready but unused). 0.1.0 ships unsigned and not notarized.

Milestones 0–8 took it from an empty repository to this release; the history is in the
merged pull requests.

## Planned

| Item | Status |
|---|---|
| **Windows app** | Being planned. No release date and no download yet. |

## After 0.1.0

Candidates, not commitments. Each needs evidence that it works reliably before it is built.

| Item | Status |
|---|---|
| **Developer ID signing and notarization** | Needs an Apple Developer Program membership. The release pipeline already supports it ([releasing.md](releasing.md)). Removes the Gatekeeper override and keeps Claude's Keychain permission across updates. |
| **Codex Keychain sign-in** (`cli_auth_credentials_store = "keyring"`) | Needs a verified capture of the item's format. Until then those installations show "Not connected". |
| **Codex 403 vs. workspace without Codex** | Needs a captured 403 response that tells the two apart. Both show "Sign-in expired" today. |
| **Refresh when the network comes back** | Today data stays marked outdated until the next scheduled refresh after an outage. |
| **Automatic update checks** | Manual checks ship with Sparkle (gear menu › Check for Updates…). Checking in the background would add a request the user did not ask for; needs a privacy-preserving design and an opt-in. |
| **More providers** (Gemini, Cursor, Copilot, …) | Only with a reliable, documented-enough source. Start with a section in [providers.md](providers.md). |
| **Menu bar customization** | Driven by dogfooding feedback. |
| **Agent alerts: Claude Code questions** | Debug-only prototype ([agents.md](agents.md)). Validated with real sessions: structured questions (`AskUserQuestion`) in the menu bar and popover, `2 → 1 → usage` as they are answered, and **Go to Session** in Terminal.app. Before a release: listener authentication, installing and removing hooks from Settings with consent, and a safe edit of `~/.claude/settings.json`. |
| **Agent alerts: more environments** | Exact targets for iTerm2, VS Code, and tmux (today: open the app, or nothing). Each needs a verified way to find and show the session. |
| **Agent alerts: Codex** | Needs a verified signal for when a Codex session asks the user something and when it is answered. |
| **Agent alerts: approvals** | Not counted: Claude Code sends no event when the user approves (only when the command finishes) or denies. Needs a reliable signal that the user has decided. |

## Not planned

Linux app, CLI, widgets, notifications, usage history, cloud sync, accounts. The
boundaries in [architecture.md](architecture.md) keep some of these possible without
building them now.
