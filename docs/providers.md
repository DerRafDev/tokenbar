# Provider data sources

This document records **where each provider's usage data comes from**, how reliable
that source is, and what it costs in security and stability. It is written *before*
the provider code and must be kept current when a source changes.

> Subscription usage (Claude Pro/Max, ChatGPT Plus/Pro) is **not** the same thing as
> API usage (Anthropic Console, OpenAI Platform). The official Anthropic and OpenAI
> usage/billing APIs only cover API keys and organizations. **Neither company
> publishes a documented API for consumer-plan limits.** Every source below is
> therefore undocumented to some degree, and TokenBar must treat it as such.

Research date: 2026-10-22. Field names marked *observed* come from community
reports and must be confirmed against a sanitized live capture before a provider
ships (see [Verification](#verification)).

---

## Claude (Pro / Max)

| | |
|---|---|
| **Authentication** | Reuse the OAuth credential that Claude Code stores in the macOS Keychain (generic password, service `Claude Code-credentials`). The item holds JSON with an access token, refresh token, expiry, and subscription type. |
| **Usage source** | `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <token>` and `anthropic-beta: oauth-2025-04-20`. This is the endpoint behind Claude Code's `/usage` command. |
| **Available metrics** | *Observed*: `five_hour`, `seven_day`, and model-scoped weekly windows (for example `seven_day_opus`, `seven_day_sonnet`), each `{ utilization: 0–100, resets_at: ISO-8601 \| null }`. |
| **Reset information** | Absolute timestamps (`resets_at`). No string parsing needed. |
| **Not available** | **Message counts** (e.g. "34 / 200 messages"). Claude limits are compute-based, not fixed message quotas, and no source exposes a count. TokenBar shows percentages only. |
| **Known limitations** | Undocumented and can change without notice. Persistent HTTP 429 responses have been reported, particularly without a Claude Code `User-Agent`. Requires Claude Code to be installed and logged in. One community report says the "weekly" window does not always reset on a 7-day cadence, so TokenBar trusts `resets_at` rather than computing windows itself. |
| **Security considerations** | macOS shows an access prompt the first time TokenBar reads another app's Keychain item; the user stays in control. TokenBar **never refreshes** the token (refresh rotates it and could sign Claude Code out), **never copies** it into its own storage, and **never logs** it. An expired token means "open Claude Code to sign in again". |
| **Policy risk** | Anthropic's Consumer Terms restrict OAuth tokens to Claude Code and Claude.ai, and a community issue flags calling this endpoint from third-party tools as a possible conflict. **Unresolved — must be decided before shipping the real provider.** |

### Alternatives considered

| Source | Verdict |
|---|---|
| `claude.ai/api/organizations/{org}/usage` with a browser `sessionKey` cookie | Rejected as default. It requires the user to paste a cookie that grants full account access. Could be an opt-in "manual" mode stored in Keychain. |
| Run `claude` in a pseudo-terminal and parse `/usage` output | Rejected. It spawns a process per refresh, is slow, and breaks on any output change. |
| Anthropic Admin / Usage & Cost API | Wrong data: API billing only. |

---

## ChatGPT (Plus / Pro)

| | |
|---|---|
| **Authentication** | Reuse the Codex CLI login (`~/.codex/auth.json`, mode `0600`, or the system keyring when Codex is configured with `cli_auth_credentials_store = "keyring"`). It contains a ChatGPT access token and account ID. |
| **Usage source** | `GET https://chatgpt.com/backend-api/wham/usage` with `Authorization: Bearer <token>` and `ChatGPT-Account-Id: <id>`. This is the internal endpoint the Codex clients use. |
| **Available metrics** | *Observed*: `plan_type`; `rate_limit.primary_window` and `rate_limit.secondary_window`, each with `used_percent`, `limit_window_seconds`, and `reset_at` (Unix seconds); optional `additional_rate_limits[]` (per-model) and `code_review_rate_limit`. The window type is identified by its length (18000 s = 5 hours, 604800 s = weekly), **not** by primary/secondary position. |
| **Reset information** | Absolute Unix timestamps. |
| **Not available** | **ChatGPT chat message limits** (for example GPT-5 messages per 3 hours in the ChatGPT app). There is no endpoint, documented or otherwise, that reports them. **What we can show is the ChatGPT plan's *Codex* usage**, not chat-message usage. Message counts are not available either. |
| **Known limitations** | Undocumented. One report shows the endpoint reporting 0% while a model-specific weekly limit was exhausted, so per-model limits must be parsed separately. Tokens from the newer "Sign in with ChatGPT" token-sharing flow are rejected (401); only a Codex login works ([openai/codex#54219](https://github.com/openai/codex/issues/54219), open, no maintainer response). |
| **Security considerations** | TokenBar reads the file at fetch time and never copies, refreshes, or logs the token. Reading `~/.codex` is incompatible with App Sandbox unless the user grants access to the folder (security-scoped bookmark). |

---

## Consequences for the product

1. **Mockup change:** remove the "N / M mensagens" lines. Keep percentage + reset.
2. **Naming honesty:** the "ChatGPT" provider reports *Codex limits on the ChatGPT
   plan*. The UI must say so (for example "ChatGPT · Codex limits"), or the
   provider should simply be called **Codex**. *Open decision.*
3. **Every provider can return partial data.** The domain model allows any limit
   to be missing and allows usage with no percentage.
4. **Prerequisites are visible.** If Claude Code / Codex is not installed or not
   signed in, the provider shows "Not connected" with a one-line instruction. It
   never shows an empty bar that looks like 0%.

## Verification

Before a provider's parser is merged:

1. Capture one real response locally (never in CI).
2. Sanitize it: remove tokens, account/org IDs, emails; replace timestamps with
   fixed values.
3. Commit it as a fixture under the provider's test folder.
4. Update the *observed* fields in this document to *verified* with the date.

## Sources

- [Claude Code authentication docs](https://code.claude.com/docs/en/authentication)
- [anthropics/claude-code#31021 — `/api/oauth/usage` persistent 429](https://github.com/anthropics/claude-code/issues/31021)
- [Claude-Code-Usage-Monitor#202 — OAuth usage API headers and Keychain item](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor/issues/202)
- [claude-hud#287 — Consumer Terms concern](https://github.com/jarrodwatts/claude-hud/issues/287)
- [Gist — weekly window cadence observation](https://gist.github.com/monperrus/3ac4b303a84946bbeaf2b1123ee99491)
- [openai/codex#54219 — no plan-usage API for token-sharing apps](https://github.com/openai/codex/issues/54219)
- [ajhochy/Rhythm#1568 — `wham/usage` structure](https://github.com/ajhochy/Rhythm/issues/1568)
- [codenotch#286 — model-level limit not reflected](https://github.com/vinzdg/codenotch/issues/286)
- [cliproxyapi-dashboard#309 — `additional_rate_limits`](https://github.com/itsmylife44/cliproxyapi-dashboard/issues/309)
- Prior art: [steipete/CodexBar](https://github.com/steipete/CodexBar)
