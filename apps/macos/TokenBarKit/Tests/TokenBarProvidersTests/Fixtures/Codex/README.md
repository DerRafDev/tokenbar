# Codex fixtures

| File | Origin |
|---|---|
| `usage-plus.json` | Live `GET /backend-api/wham/usage` response (Plus plan, 2026-10-22), sanitized: same structure, every value replaced, timestamps fixed relative to the tests' clock (2027-01-15 08:00 UTC). Dropped: `email`, `user_id`, `account_id`, `model_usage`, and `rate_limit_reset_credits`. |
| `usage-idle.json` | Same shape as a live response with no active 5-hour window: 0% and a reset that is "now + 5 hours". |
| `usage-pro-model-limits.json` | Synthetic. Windows in reverse order (weekly first), a model-specific `additional_rate_limits` entry in the shape of Codex's own client models (open source), an entry without limits, and an unknown key. |
| `usage-partial.json` | Synthetic. 5-hour window `null`. |
| `usage-missing-fields.json` | Synthetic. A window without `used_percent` or `reset_at`, a 1-hour window TokenBar cannot name, and an unknown plan. |

Never commit an unsanitized response. Its body contains the account's email, user ID and
account ID, and its headers set cookies.
