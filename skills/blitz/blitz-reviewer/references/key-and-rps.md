# API key, RPS & records (check 7)

Read the key's health and surface throughput the integration isn't using. `key_info` is a **free**
call that spends no records. Get it via the SDK (preferred, proves the SDK works end-to-end) or the
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

All three hit `GET /v2/account/key-info`. Confirm the current field set in the docs
(`cat /api-reference/account/get-api-key-details.mdx` and
`cat /guide/getting-started/authentication.mdx`) or the OpenAPI response schema — these are the
actionable fields:

| field | meaning | flag when |
|-------|---------|-----------|
| `valid` | key is active | **✗** if false/expired — nothing else will work |
| `records_remaining` | records left on the plan's fair-usage allowance until `next_reset_at` — a number, e.g. `5000000` | **⚠** if low relative to the planned job (each search result and each successful enrichment is one record); **✗** at `0` |
| `next_reset_at` | when the monthly allowance resets (unused records don't carry over) | report it when the balance is short |
| `max_requests_per_seconds` | the plan's RPS **per endpoint** (a number that differs by plan, e.g. `25`) | compare against the code (below) |
| `allowed_apis` | endpoint paths the key may call, **without** the `/v2` prefix (older aliases may also appear) | **✗** if code calls a path not in the list |
| `active_plans` | plan name / status / start date | read it to explain a limit (e.g. phone is not part of the free trial → **✗** if the code calls phone on a trial key) |

(The payload also carries `id` and `fair_usage`.) Mask the key (`sk_…last4`) wherever it is shown.

## RPS is per endpoint

Blitz enforces its rate limit **per endpoint**: `/enrichment/email`, `/enrichment/phone`,
`/search/people`, … each have an independent budget, and `max_requests_per_seconds` is the limit
for each of them. Every metered response reports live headroom in `fair_usage.rate_limit`
(`requests_per_second`, `remaining_this_second`). The SDK's client-side limiter matches:
`blitz-api-py` and `blitz-api-js` keep one sliding window / token bucket *per endpoint path* inside
a client, so one shared client per process already stays under the limit on every endpoint and runs
`/email` and `/phone` side by side.

## Are you leaving throughput on the table?

Two numbers:

- **Allowed RPS** — `max_requests_per_seconds` from `key_info` (what each endpoint permits).
- **Configured RPS** — the SDK client's `rate_limit_rps` in the user's code. It **defaults to 5**
  and is enforced client-side, per endpoint.

Find `rate_limit_rps` in the code (grep from `code-audit.md`) and compare:

- **Configured < allowed (⚠):** the integration throttles itself below what the plan permits — a
  large job runs slower than it has to. Most often it is just *unset*, so it runs at the SDK
  default of 5 on a plan that allows more. Fix: set `rate_limit_rps` to `max_requests_per_seconds`
  (read it from `key_info`), e.g. `BlitzAPI(rate_limit_rps=10)` /
  `new BlitzAPI({ rate_limit_rps: 10 })`. It only matters for runs that are limiter-bound — a
  synchronous loop that's already slower than 5 req/s per endpoint gains nothing.
- **Several workers on one endpoint (⚠):** the limiter lives on the client *instance*, so five
  processes or workers that all call `/enrichment/email` at `rate_limit_rps=10` fire 50 req/s at an
  endpoint that allows 10 — expect `429`s. Divide `rate_limit_rps` across the workers sharing an
  endpoint (5 workers on a 10 rps key → 2 each). Workers on *different* endpoints don't compete.
- **Configured > allowed:** the server enforces the real per-endpoint ceiling and the SDK retries
  on 429, so a higher setting buys nothing — note it and leave it.

## Wanting a *higher* allowed RPS or more records — ask first

`key_info` reports the current allowance, not a catalog of higher tiers. If the job needs more
throughput than the key's `max_requests_per_seconds` allows — after already setting `rate_limit_rps`
to it — or `records_remaining` won't cover the run before `next_reset_at`, **surface it and ask**;
plan changes are the user's call:

> "Each endpoint allows N RPS and you're already configured at N. Going faster needs a higher plan
> tier — want me to point you to where to upgrade?"

Then redirect to the Blitz app / plan settings at https://app.blitz-api.ai (pricing:
https://docs.blitz-api.ai/guide/concepts/pricing). Any actual code change to `rate_limit_rps` still
goes through the confirmation-gated remediation queue like every other fix.
