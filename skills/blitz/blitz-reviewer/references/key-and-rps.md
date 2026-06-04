# API key, RPS & credits (check 7)

Read the key's health and surface throughput the integration isn't using. This is a **free** call —
`key_info` spends no credits. Get it via the SDK (preferred, proves the SDK works end-to-end) or the
dependency-free script:

```python
client.account.key_info()   # blitz-api-py
```
```ts
await client.account.key_info()   // blitz-api-js
```
```bash
BLITZ_API_KEY=… bash scripts/check_key.sh   # curl + jq fallback, no SDK needed
```

All three hit `GET /v2/account/key-info`. Confirm the current field set against the MCP
(`cat /api-reference/account/get-api-key-details.mdx`, or the OpenAPI response schema) rather than
assuming it — these are the actionable ones:

| field | meaning | flag when |
|-------|---------|-----------|
| `valid` | key is active | **✗** if false/expired — nothing else will work |
| `remaining_credits` | usage allowance left (**trial accounts only — paid plans are unlimited**) | **⚠** if a trial key is low relative to the planned job |
| `max_requests_per_seconds` | RPS this key is *allowed* (5 standard; higher on some plans) | compare against the code (below) |
| `allowed_apis` | endpoint paths the key may call | **✗** if code calls a path not in the list |

(The payload also carries `id`, `next_reset_at`, and `active_plans` — read them from the MCP when
relevant.) Never print the full key — mask it (`sk_…last4`).

## RPS: are you leaving throughput on the table?

Two distinct numbers:

- **Allowed RPS** — `max_requests_per_seconds` from `key_info` (what the plan permits).
- **Configured RPS** — the SDK client's `rate_limit_rps` in the user's code (what they actually
  use). The SDK throttles to this client-side. Default is conservative.

Find `rate_limit_rps` in the code (grep from [code-audit.md](code-audit.md)) and compare:

- **Configured < allowed (⚠):** the integration is throttling itself below what the plan permits —
  a large job runs slower than it has to. Fix: raise `rate_limit_rps` toward the allowed ceiling.
  Example: `BlitzAPI(rate_limit_rps=10)` / `new BlitzAPI({ rate_limit_rps: 10 })` when allowed is 10.
- **Configured not set (⚠, minor):** the SDK uses its default throttle; if it's below allowed, the
  same waste applies — suggest setting it explicitly to the allowed value.
- **Configured > allowed:** the server enforces the real ceiling anyway (the SDK retries on 429),
  so this isn't a throughput win — note it but don't "fix" it upward past `allowed`.

## Wanting a *higher* allowed RPS or more credits — ask first

`key_info` reports the current allowance, not a catalog of higher tiers. If the job needs more
throughput than `max_requests_per_seconds` allows, or `remaining_credits` won't cover it, **surface
it and ask** — don't initiate any plan change yourself:

> "Your key allows N RPS and you're already configured at N. Going faster needs a higher tier —
> want me to point you to where to upgrade?"

Then redirect to the user's Blitz dashboard / plan settings at https://blitz-api.ai (or the docs,
https://docs.blitz-api.ai). Any actual code change to `rate_limit_rps` still goes through the
confirmation-gated remediation queue like every other fix.
