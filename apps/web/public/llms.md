# TokenBar

## What is TokenBar?

TokenBar is a free and open-source app for monitoring AI usage limits from the system menu bar. Instead of opening a provider's dashboard or running a command in a terminal, you see how much of each plan limit you have used, and when it resets, at a glance.

TokenBar is built around AI usage in general, not around one vendor. Today it supports two providers, Claude and Codex, and its architecture lets more providers be added over time.

Website: https://tokenbar.si/

## Key facts

- Free. No subscription, no paid plan, no pricing.
- Open source under the MIT License.
- Native macOS app, built with Swift, SwiftUI and AppKit. No Electron, no web views, no third-party runtime dependencies.
- An AI usage monitor that lives in the menu bar. It has no Dock icon and no window.
- No TokenBar account and no TokenBar backend or server.
- No analytics, telemetry, crash reporting, tracking, update checks or cloud sync.
- Currently supports Claude and Codex. Both integrations are experimental.
- macOS is available now. A Windows version is planned.

## Supported platforms

### macOS

Available now. Requires macOS 14 Sonoma or later, on Apple silicon or Intel.

### Windows

Planned. There is no Windows release, no Windows download, and no release date yet.

## Supported AI providers

Both integrations are experimental. Neither Anthropic nor OpenAI publishes an API for plan limits, so TokenBar uses the same undocumented endpoints that Claude Code and Codex use to show usage. They may change or stop working at any time, and the providers' terms may not cover this use. Every provider starts disabled; TokenBar explains what it reads before the user enables it.

### Claude

Supported now (Claude Pro and Max plans). Shows the current session (5 hours) and weekly limits, plus Opus and Sonnet weekly limits when the plan has them, each with its reset time. Requires Claude Code signed in on the same Mac; TokenBar reads Claude Code's sign-in from the macOS Keychain when it refreshes.

### Codex

Supported now (ChatGPT plans). Shows Codex 5-hour and weekly limits, plus model-specific limits when the plan has them, each with its reset time. These are Codex limits, not ChatGPT chat message limits. Requires Codex (CLI or app) signed in with ChatGPT on the same Mac; TokenBar reads `~/.codex/auth.json`. Codex installations that keep their sign-in in the Keychain are not supported yet.

### More providers

Each provider implements one protocol (`UsageProvider`) and returns a normalized usage snapshot, so a new provider does not require changes to the menu bar, popover or refresh logic. A provider is added only when it has a reliable, documented-enough data source. No other provider is confirmed.

## Features

- Usage in the menu bar: each provider's logo with its current session percentage.
- Three menu bar display modes: Providers (one number per provider, the default), Minimal (only the provider whose session is most used) and Detailed (session and week, like `15/12`).
- Popover with every enabled provider in one line; expand one to see each limit with a bar and its reset time.
- Current session and weekly limits, and model-specific limits where the provider reports them.
- Reset information computed locally in the user's time zone, for example "Resets at 19:10 (in 2h 50m)" or "Resets in 2d 14h (Sat, Oct 25 at 07:00)".
- Usage levels: values are highlighted from 70% and marked as critical from 90%.
- Automatic refresh every 5 minutes by default (2–15 minutes, configurable), after the Mac wakes, and when the popover opens.
- If a refresh fails, the last values stay visible and are marked as outdated.
- Launch at Login (optional).
- English and Portuguese (Brazil).

## Privacy

- No TokenBar account.
- No TokenBar backend. Requests go directly from the user's Mac to the provider endpoints (`api.anthropic.com` for Claude, `chatgpt.com` for Codex), and only for providers the user enabled.
- No telemetry, no analytics, no crash reporting, no tracking and no update checks in the macOS app.
- Usage data is kept in memory and never written to disk. Network responses are not cached and cookies are not stored.
- Credentials are not copied into TokenBar-owned storage. TokenBar reads the existing Claude Code or Codex sign-in at refresh time and never stores, copies, refreshes or logs it.
- Preferences (refresh interval, enabled providers, menu bar mode) are stored in the standard macOS preferences file.
- The website has no analytics and sets no cookies.

## Open Source

- GitHub repository: https://github.com/DerRafDev/tokenbar
- License: MIT (https://github.com/DerRafDev/tokenbar/blob/main/LICENSE)
- Contributions are welcome: https://github.com/DerRafDev/tokenbar/blob/main/CONTRIBUTING.md
- Issue tracker: https://github.com/DerRafDev/tokenbar/issues
- Security reports are handled privately: https://github.com/DerRafDev/tokenbar/security/advisories/new

## Download

**macOS — Available now.** Download the latest release from https://github.com/DerRafDev/tokenbar/releases/latest (a `.dmg` and a `.zip`, with SHA-256 checksums in `SHA256SUMS.txt`).

**Windows — Planned.** No download yet.

The current macOS build is unsigned and not notarized by Apple, so macOS Gatekeeper blocks the first launch. To open it: open TokenBar once, then go to System Settings › Privacy & Security, find the message about TokenBar, click Open Anyway and confirm. This approves TokenBar only; Gatekeeper should not be turned off for the whole Mac. Developer ID signing and notarization are on the roadmap.

## Roadmap

There are no dates. Source: https://github.com/DerRafDev/tokenbar/blob/main/docs/roadmap.md

- **Shipped — v0.1.0:** native macOS menu bar app; experimental Claude and Codex providers; session and weekly limits with reset countdowns; menu bar display modes; automatic refresh; launch at login; English and Portuguese (Brazil).
- **Planned:** a Windows version. No release date.
- **After 0.1.0 (candidates, not commitments; each needs evidence that it works reliably before it is built):** Developer ID signing and notarization; Codex Keychain sign-in; telling a Codex 403 apart from a workspace without Codex; refresh when the network comes back; automatic updates (needs a privacy-preserving design); more providers (only with a reliable, documented-enough source); menu bar customization.

## Canonical links

- Website: https://tokenbar.si/
- GitHub: https://github.com/DerRafDev/tokenbar
- Releases: https://github.com/DerRafDev/tokenbar/releases
- Latest release: https://github.com/DerRafDev/tokenbar/releases/latest
- Issues: https://github.com/DerRafDev/tokenbar/issues
- License: https://github.com/DerRafDev/tokenbar/blob/main/LICENSE
- Roadmap: https://github.com/DerRafDev/tokenbar/blob/main/docs/roadmap.md
- Provider data sources: https://github.com/DerRafDev/tokenbar/blob/main/docs/providers.md
- Architecture: https://github.com/DerRafDev/tokenbar/blob/main/docs/architecture.md

TokenBar is not affiliated with Anthropic or OpenAI. Claude, ChatGPT and Codex are trademarks of their respective owners.
