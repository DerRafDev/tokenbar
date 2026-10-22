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

## Claude (Pro / Max) — experimental

Verified against live responses on 2026-10-22 (Claude Code 2.1.116, Pro plan).

| | |
|---|---|
| **Usage source** | `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <token>` and `anthropic-beta: oauth-2025-04-20`. This is the endpoint behind Claude Code's `/usage` command (Claude Code calls it with a 5 s timeout and skips it when its token has expired). TokenBar sends its own `User-Agent` (`TokenBar/<version>`) and never impersonates Claude Code. |
| **Response** (*verified*) | JSON object. Windows `five_hour`, `seven_day`, `seven_day_opus`, `seven_day_sonnet` (and others), each `{ "utilization": 0–100, "resets_at": "2026-10-22T23:09:59.987225+00:00", … }` or `null` when the window does not apply to the plan. Also: a normalized `limits[]` list (`kind`, `group`, `percent`, `resets_at`, `scope`), `extra_usage`, `spend`, a per-product `seven_day_breakdown`, and many internal codenamed keys. TokenBar reads only the four named windows and ignores the rest. |
| **What `five_hour` is** | A **session**, not a rolling window. Evidence: (1) the server's own `limits[]` entry for it has `kind: "session"`; (2) Claude Code labels it "session limit" (`windowSeconds: 18000`); (3) in two captures 19 s apart, utilization rose 45 → 46 % while `resets_at` stayed at 23:10:00 — a rolling window's reset would have moved. Mapped to `LimitWindow.session`. |
| **What `seven_day` is** | A fixed weekly window: `seven_day_breakdown.window_started_at` is exactly 7 days before `resets_at`. Mapped to `.weekly`. `seven_day_opus` / `seven_day_sonnet` → `.weekly` with scope "Opus" / "Sonnet". |
| **Reset information** | ISO 8601 with microseconds and sub-second jitter around the real boundary (`23:09:59.987`, then `23:10:00.278`). TokenBar rounds to the second. |
| **Not available** | Message counts. Limits are percentages only. |
| **Errors** (*verified*) | Invalid or missing token → HTTP 401 with a JSON error body. TokenBar never reads error bodies. |
| **Known limitations** | Undocumented; can change without notice. Requires Claude Code installed and signed in on the same Mac. Persistent HTTP 429s have been reported by other tools; TokenBar honors `Retry-After` and backs off. |
| **Policy risk** | Anthropic's Consumer Terms restrict OAuth tokens to Claude Code and Claude.ai, and a community issue flags calling this endpoint from third-party tools as a possible conflict. Shown to the user before enabling. See the decision below. |

### Authentication

| Question | Answer |
|---|---|
| Where does authentication originate? | Claude Code's own OAuth sign-in (`claude auth login`). TokenBar has no sign-in flow. |
| Does TokenBar read the Keychain? | Yes, **one item**: generic password, service `Claude Code-credentials`, owned by Claude Code. Read-only, with `SecItemCopyMatching`, on every refresh while the provider is enabled. Never before the user enables the provider. |
| What exactly is read? | The item holds JSON with an access token, refresh token, expiries, scopes, plan, and organization ID. TokenBar decodes **only** `claudeAiOauth.accessToken`, `expiresAt`, and `subscriptionType` (shown as the plan badge). The refresh token and organization ID are never decoded. |
| Do credentials enter TokenBar's memory? | Yes, the access token, for the duration of one refresh: it is parsed, put in one request header to `api.anthropic.com`, and released. Its `description` is redacted so it cannot leak through logging or string interpolation. |
| Is anything persisted? | No. No copy in TokenBar's Keychain, `UserDefaults`, or files. Requests use an ephemeral `URLSession` with no URL cache, cookies, or credential storage, so the response never reaches the disk either. |
| Who grants access? | macOS. The first read shows "TokenBar wants to use your confidential information stored in 'Claude Code-credentials'". *Deny* → TokenBar shows "Access was not allowed" and does not ask again until the user refreshes manually. *Always Allow* is tied to TokenBar's code signature: Developer ID builds keep it across updates; ad-hoc local builds are asked again after each rebuild. |
| Claude Code logged out? | The item is gone → "Not connected". Old numbers are cleared. |
| Credentials expired? | TokenBar checks `expiresAt` and does **not** call the endpoint with an expired token; it shows "Sign-in expired". TokenBar never refreshes the token (that would rotate Claude Code's refresh token and could sign it out). Claude Code renews it the next time it runs, and TokenBar picks up the new token on its next refresh. |
| Credentials changed? | Claude Code updates the item in place (creation date unchanged), so the user's Keychain decision survives; the new token is read on the next refresh. |

### Least invasive option

| Option | Verdict |
|---|---|
| **Read Claude Code's Keychain item at fetch time** | **Chosen.** No copy, no refresh, user-visible macOS consent, always current. |
| Claude Code `statusLine` hook (its input JSON has `rate_limits.five_hour/seven_day`) | Zero credential access, but requires replacing the user's status line command, only updates while Claude Code is running (claude.ai usage is missed), and lacks model-specific limits. Possible future fallback. |
| Ask the user to paste a `claude.ai` session cookie | Rejected: grants full account access and would have to be stored. |
| Read rate-limit headers from a real API request | Rejected: costs usage. |
| Run `claude` and parse `/usage` | Rejected: a process per refresh, breaks on any output change. |

### Decision (2026-10-22)

Claude ships as an **experimental, opt-in** provider:

- Disabled by default. TokenBar never reads the Claude Code sign-in until the user
  enables the provider and confirms a Claude-specific warning: undocumented endpoint,
  may change or stop working, may not be covered by Anthropic's terms, and what is read.
- Labeled "Experimental" wherever it appears.
- Isolated behind `UsageProvider` in `TokenBarProviders/Claude/`, so the data source can
  be replaced (or the provider removed) without touching the UI, refresh logic, or
  other providers. The app references it in one line of `ProviderRegistry`.

---

## Codex (ChatGPT plans)

| | |
|---|---|
| **Authentication** | Reuse the Codex CLI login (`~/.codex/auth.json`, mode `0600`, or the system keyring when Codex is configured with `cli_auth_credentials_store = "keyring"`). It contains a ChatGPT access token and account ID. |
| **Usage source** | `GET https://chatgpt.com/backend-api/wham/usage` with `Authorization: Bearer <token>` and `ChatGPT-Account-Id: <id>`. This is the internal endpoint the Codex clients use. |
| **Available metrics** | *Observed*: `plan_type`; `rate_limit.primary_window` and `rate_limit.secondary_window`, each with `used_percent`, `limit_window_seconds`, and `reset_at` (Unix seconds); optional `additional_rate_limits[]` (per-model) and `code_review_rate_limit`. The window type is identified by its length (18000 s = 5 hours, 604800 s = weekly), **not** by primary/secondary position. |
| **Reset information** | Absolute Unix timestamps. |
| **Not available** | **ChatGPT chat message limits** (for example GPT-5 messages per 3 hours in the ChatGPT app). There is no endpoint, documented or otherwise, that reports them. **What we can show is the ChatGPT plan's *Codex* usage**, not chat-message usage. Message counts are not available either. |
| **Window semantics** | To be verified against a live capture: whether the 5-hour window is rolling or starts with first use. TokenBar models whatever the source actually represents (`LimitWindow.rolling` vs `.session`) and never relabels it to match another provider. |
| **Known limitations** | Undocumented. One report shows the endpoint reporting 0% while a model-specific weekly limit was exhausted, so per-model limits must be parsed separately. Tokens from the newer "Sign in with ChatGPT" token-sharing flow are rejected (401); only a Codex login works ([openai/codex#54219](https://github.com/openai/codex/issues/54219), open, no maintainer response). |
| **Security considerations** | TokenBar reads the file at fetch time and never copies, refreshes, or logs the token. Reading `~/.codex` is incompatible with App Sandbox unless the user grants access to the folder (security-scoped bookmark). |

---

## Consequences for the product

1. **Mockup change:** remove the "N / M mensagens" lines. Keep percentage + reset.
2. **Naming honesty (decided 2026-10-22):** the provider is called **Codex** (id
   `codex`), because it reports Codex limits on a ChatGPT plan, not ChatGPT message
   limits. Nothing in the UI may imply otherwise. The id `chatgpt` stays free for a
   separate ChatGPT provider if a reliable source for chat limits ever appears.
3. **Semantic limits:** each limit is modeled as the window the provider actually
   reports (session, rolling window of a given length, daily, weekly, monthly,
   optionally scoped to a model). Providers are never forced into a common
   "session + weekly" shape to look consistent.
4. **Every provider can return partial data.** The domain model allows any limit
   to be missing and allows usage with no percentage.
5. **Consent first.** Every provider that reads another app's credentials is
   disabled until the user enables it in Settings.
6. **Prerequisites are visible.** If Claude Code / Codex is not installed or not
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
