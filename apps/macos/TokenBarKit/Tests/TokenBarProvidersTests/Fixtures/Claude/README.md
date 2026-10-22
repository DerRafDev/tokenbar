# Claude fixtures

| File | Origin |
|---|---|
| `usage-pro.json` | Live `GET /api/oauth/usage` response (Pro plan, 2026-10-22), sanitized: same structure, every value replaced, timestamps fixed in January 2026. Internal codenamed keys, billing (`spend`) and identifiers dropped. Sub-second `resets_at` jitter kept on purpose. |
| `usage-max-model-limits.json` | Synthetic. Same window shape, with the model-specific weekly windows a Max plan reports, plus an unknown key. |
| `usage-partial.json` | Synthetic. Session window `null`. |
| `usage-missing-fields.json` | Synthetic. Windows without `utilization` or `resets_at`, and an invalid date. |

Never commit an unsanitized response. Tokens live in request headers, but responses
carry account data in headers (`anthropic-organization-id`) and could gain more fields.
