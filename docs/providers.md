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
ships (see [Verification](#verification)). Both providers below are *verified*.

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
| Does TokenBar read the Keychain? | Yes, **one item**: generic password, service `Claude Code-credentials`, owned by Claude Code. Read-only, with `SecItemCopyMatching`, while the provider is enabled; never before the user enables it. Each refresh reads only the item's **attributes** (modification date), which does not touch the secret and shows no prompt (checked with an ad-hoc-signed binary outside the item's access list). The item's **data** is read when nothing is cached, when the modification date changed (Claude Code renewed the token, signed in to another account), or when the cached token expired or was rejected — then at most once every 15 minutes, so a token renewed without a new modification date is still picked up. See `ClaudeCredentialCache`. |
| What exactly is read? | The item holds JSON with an access token, refresh token, expiries, scopes, plan, and organization ID. TokenBar decodes **only** `claudeAiOauth.accessToken`, `expiresAt`, and `subscriptionType` (shown as the plan badge). The refresh token and organization ID are never decoded. |
| Do credentials enter TokenBar's memory? | Yes, the access token, plan, and expiry, kept in memory while TokenBar runs so the Keychain is not read on every refresh. The token is only put in one request header to `api.anthropic.com`. Its `description` is redacted so it cannot leak through logging or string interpolation. The memory copy is gone when TokenBar quits. |
| Is anything persisted? | No. The in-memory copy is never written anywhere: no copy in TokenBar's Keychain, `UserDefaults`, or files. Requests use an ephemeral `URLSession` with no URL cache, cookies, or credential storage, so the response never reaches the disk either. |
| Who grants access? | macOS. The first read shows "TokenBar wants to use your confidential information stored in 'Claude Code-credentials'". *Deny* → TokenBar shows "Access was not allowed" and does not ask again until the user refreshes manually. *Always Allow* is tied to TokenBar's code signature: Developer ID builds keep it across updates; ad-hoc local builds are asked again after each rebuild. |
| Claude Code logged out? | The item is gone (seen by the attribute read) → the in-memory copy is dropped, "Not connected". Old numbers are cleared. |
| Credentials expired? | TokenBar checks `expiresAt` (with a 60-second margin) and does **not** call the endpoint with an expired token; it shows "Sign-in expired". TokenBar never refreshes the token (that would rotate Claude Code's refresh token and could sign it out). Claude Code renews it the next time it runs, and TokenBar picks up the new token on its next refresh (or within 15 minutes if the item's modification date did not change). |
| Token rejected? | Checked against the live endpoint and Claude Code 2.1.116 (2026-10-27): an invalid, expired, or missing token gets **HTTP 401** `authentication_error`. Claude Code also treats **403** with "OAuth token has been revoked" as a bad token; other 401/403 bodies cover organization policy ("OAuth authentication is currently not allowed for this organization"). TokenBar drops the cached token on 401 or a revoked 403 and never sends that token again; other 403s keep it. All show "Sign-in expired". A real 403 has not been observed. |
| Credentials changed? | Claude Code updates the item in place (creation date unchanged), so the user's Keychain decision survives; its modification date changes, so the new token is read on the next refresh. |

### Least invasive option

| Option | Verdict |
|---|---|
| **Read Claude Code's Keychain item, keep the token in memory** | **Chosen.** No persisted copy, no refresh, user-visible macOS consent, current within one refresh of a renewal. Reading the item on every refresh (the first version) could show the prompt on every refresh for builds without *Always Allow*. |
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

## Codex (ChatGPT plans) — experimental

Verified against live responses and Codex's own session logs on 2026-10-22 (Plus plan),
and against the open-source Codex client ([openai/codex](https://github.com/openai/codex),
`codex-rs/backend-client`).

| | |
|---|---|
| **Usage source** | `GET https://chatgpt.com/backend-api/wham/usage` with `Authorization: Bearer <token>` and `ChatGPT-Account-Id: <id>`. This is the endpoint Codex calls for `/status` and its usage warnings. The account header is optional for a personal account (verified) and selects the workspace for team accounts; TokenBar sends it like Codex does. TokenBar sends its own `User-Agent` (`TokenBar/<version>`), which the endpoint accepts (verified), and never impersonates Codex. |
| **Response** (*verified*) | JSON object: `plan_type`; `rate_limit` with `primary_window` / `secondary_window`, each `{ "used_percent": 0–100 (integer), "limit_window_seconds", "reset_after_seconds", "reset_at": Unix seconds }` or `null`; `additional_rate_limits` (`null` on Plus; per Codex's client: `[{ "limit_name", "metered_feature", "rate_limit": {…same shape…} }]` for models with their own quota); plus `credits`, `spend_control`, `rate_limit_reached_type`, `rate_limit_reset_credits`, `model_usage`, `promo`, and the account's **email, user ID and account ID**. TokenBar declares only `plan_type`, `rate_limit` and `additional_rate_limits`; the identifiers are never decoded. `code_review_rate_limit` is present but no longer read by Codex, so TokenBar ignores it. |
| **Window types** | Identified by `limit_window_seconds` (`18000` = 5 hours, `604800` = 7 days), never by primary/secondary position. Observed: primary = 5 h, secondary = 7 d. Lengths TokenBar cannot name are skipped, not mislabeled. |
| **What the 5-hour window is** | A **session-like fixed window**, not a rolling one. It starts with the first request after the previous window ended and resets at a fixed time. Evidence from Codex's own per-turn logs: usage rose 3 → 48 % over 4.5 hours while `reset_at` stayed at the same second; after it expired, the next response showed 0 % with `reset_at` = request time + 5 h, and that value moved with every request until usage started a new window. Mapped to `LimitWindow.session`. Codex itself just calls it the "5h limit". |
| **What the weekly window is** | The same mechanism over 7 days: anchored at the first use after the previous week ended, not a calendar week. Mapped to `.weekly`. It can also reset early: one observation went from 9 % to a new window two days before its `reset_at` (consistent with an OpenAI-side reset or a redeemed reset credit). TokenBar shows whatever the latest response says. |
| **Reset information** | `reset_at` as absolute Unix seconds (stable to the second; ±3 s jitter between the idle and started values). TokenBar uses `reset_at`, falls back to `reset_after_seconds` relative to the fetch time, and **hides** the reset of a window that has not started (0 % and a full window left), because that value is only "now + length". |
| **Model-specific limits** | `additional_rate_limits[]` → limits scoped to `limit_name` (id `<window>.<metered_feature>`). None on the verified Plus account; the shape comes from Codex's client models. A community report shows a model limit exhausted while the main windows read 0 %, so they are parsed separately. |
| **Plan** | `plan_type` from the response (`plus` verified; `free`, `go`, `pro`, `team`, `business`, `enterprise`, `edu` named; unknown values hidden). The JWT also carries the plan, but TokenBar does not decode the token. |
| **Not available** | **ChatGPT chat message limits.** This endpoint reports **Codex** limits on a ChatGPT plan. Message counts are not available either (`credits.approx_*_messages` belongs to purchased credits in Codex's client, not to plan limits; TokenBar ignores it). |
| **Errors** (*verified*) | Invalid or missing token → HTTP 401 with a JSON `detail` body. 403, 429 and `Retry-After` were not observed; they follow the shared rules (403 → "Sign-in expired", 429 → back off, honoring `Retry-After` in seconds or as an HTTP date). A 403 could also mean Codex is not available for the workspace, but no captured response distinguishes the two, so TokenBar does not guess: it shows "Sign-in expired" for both (reviewed for 0.1.0). TokenBar never reads error bodies. The response sets cookies; the provider session stores none. |
| **Known limitations** | Undocumented; can change without notice. Requires Codex (CLI or app) signed in with ChatGPT on the same Mac. Tokens from the newer "Sign in with ChatGPT" token-sharing flow are rejected (401); only a Codex login works ([openai/codex#54219](https://github.com/openai/codex/issues/54219)). |
| **Policy risk** | OpenAI does not offer this endpoint to third-party apps. Shown to the user before enabling. |

### Authentication

| Question | Answer |
|---|---|
| Where does authentication originate? | Codex's own "Sign in with ChatGPT" (CLI `codex login` or the Codex app). TokenBar has no sign-in flow. |
| Where is it stored? | By default `$CODEX_HOME/auth.json` (`~/.codex/auth.json`), mode `0600`, owned by the user. Codex can instead use the Keychain (`cli_auth_credentials_store = "keyring"` or `"auto"`: service `Codex Auth`, account `cli|<first 16 hex of SHA-256 of the Codex home path>`). |
| What does TokenBar read? | The file only, read-only, on every refresh while the provider is enabled. Never before the user enables it. It holds JSON with `auth_mode`, an optional API key, `tokens` (`id_token`, `access_token`, `refresh_token`, `account_id`) and `last_refresh`. TokenBar decodes **only** `tokens.access_token` and `tokens.account_id`. The refresh token, ID token (email, name) and API key are never decoded. |
| Do credentials enter TokenBar's memory? | Yes, the access token and account ID, for the duration of one refresh: put in two request headers to `chatgpt.com` and released. Their `description` is redacted. |
| Is anything persisted? | No. The in-memory copy is never written anywhere: no copy in TokenBar's Keychain, `UserDefaults`, or files. Requests use the ephemeral provider session (no cache, cookies, or credential storage). |
| Who grants access? | The user, by enabling the provider. Unlike Keychain items, a file in the user's home folder has no per-app macOS prompt (TokenBar is not sandboxed). An unreadable file is reported as "Access was not allowed". |
| Codex logged out? | `codex logout` deletes `auth.json` → "Not connected". Signed in with an API key instead of ChatGPT (no `tokens`) → "Not connected": API-key usage has no plan limits. |
| Keychain storage mode? | **Not supported.** With `keyring` (or `auto` when Codex chose the Keychain) there is no file → "Not connected". The item's format has not been verified against a live capture, so TokenBar does not read it. |
| Credentials expired? | The access token is a JWT valid ~10 days; Codex refreshes it when it is within minutes of expiring or `last_refresh` is older than 8 days. TokenBar does not decode the expiry; an expired token gets HTTP 401 → "Sign-in expired". TokenBar never refreshes the token (that would rotate Codex's refresh token and could sign Codex out). Running Codex renews it, and TokenBar picks up the new file on its next refresh. |

### Least invasive option

| Option | Verdict |
|---|---|
| **Read `auth.json` at fetch time, two fields** | **Chosen.** No copy, no refresh, always current, same file Codex reads. |
| Read Codex's session logs (`~/.codex/sessions/**/*.jsonl` carry `rate_limits` per turn) | Zero network and no token, but only updates while Codex is used, misses usage from other devices, and parses an internal log format. Used here as evidence, not as a source. |
| Run `codex` and parse `/status` | Rejected: a process per refresh, breaks on any output change. |
| Copy the token into TokenBar's Keychain | Rejected: a second copy that goes stale when Codex refreshes it. |

### Decision (2026-10-22)

Codex ships as an **experimental, opt-in** provider, isolated in `TokenBarProviders/Codex/`
and referenced in one line of `ProviderRegistry`. Disabled by default; enabling it shows a
Codex-specific warning (undocumented endpoint, may change, may not be covered by OpenAI's
terms, Codex limits only) and what is read. The 5-hour limit is shown as a session
("Session 12% · Week 42%", "Current session") because that is how the source behaves.

---

## Consequences for the product

1. **No message counts:** neither source reports them. TokenBar shows percentage + reset.
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
- [openai/codex — `codex-rs/backend-client` (usage request and response models)](https://github.com/openai/codex/tree/main/codex-rs/backend-client)
- [openai/codex#54219 — no plan-usage API for token-sharing apps](https://github.com/openai/codex/issues/54219)
- [ajhochy/Rhythm#1568 — `wham/usage` structure](https://github.com/ajhochy/Rhythm/issues/1568)
- [codenotch#286 — model-level limit not reflected](https://github.com/vinzdg/codenotch/issues/286)
- [cliproxyapi-dashboard#309 — `additional_rate_limits`](https://github.com/itsmylife44/cliproxyapi-dashboard/issues/309)
- Prior art: [steipete/CodexBar](https://github.com/steipete/CodexBar)
