# Error handling and key safety (baseline for every generated script)

## API-key safety (always)
- Read the key from `BLITZ_API_KEY` (env). Never hardcode it; never log it.
- Use a `.env` file and add it to `.gitignore`:
  ```
  # .env
  BLITZ_API_KEY=sk_your_key_here
  ```
  ```
  # .gitignore
  .env
  gtm-brief.yaml   # optional: the brief can hold business-sensitive ICP details
  leads.csv
  ```
- Python: `uv run --env-file .env script.py`, or `python-dotenv`, or export the var.
  TypeScript: `bun --env-file=.env run script.ts` (bun runs TS natively), or — without bun —
  install `tsx` and run `node --env-file=.env --import tsx script.ts` (Node 20.6+); `npx tsx
  script.ts` works for a quick run if the env is already exported.
  JavaScript: `node --env-file=.env script.mjs` (Node 20.6+), or `bun --env-file=.env run
  script.mjs` — no TS runtime needed.
- The key goes in the `x-api-key` header (the SDK does this). Never call Blitz from browser /
  mobile client code — backend only.

## Preflight (fail fast)
Call `account.key_info()` before the run. Stop early on:
- `valid == false` → bad/rotated key.
- `remaining_credits == 0` / plan exhausted.
- the endpoint you need is not in `allowed_apis` (e.g. phone needs the Phone plan).

## What the SDK already handles
Pagination, client-side rate-limiting (`rate_limit_rps`, default ~5), and retries on 429 / 5xx /
network errors with backoff (`max_retries`, default 3). Do not re-implement these. Do not lower
`max_retries` to 0.

Rate limits are enforced **per endpoint**, and the SDK's limiter is **per client instance** — one
client's `rate_limit_rps` caps total output across every endpoint it calls. For a job that hits two
endpoints under load (e.g. `/enrichment/email` and `/enrichment/phone`), use a **separate client per
endpoint** so each runs at its own per-endpoint limit concurrently instead of sharing one budget.
One client is fine when the job calls a single endpoint, or when calls are sequential.

## Cases the generated script MUST handle
| Case | How |
|------|-----|
| Bad key (401) | preflight `key_info().valid`; exit with a clear message |
| Plan/credits (402) | preflight `remaining_credits`; tell the user which plan is needed |
| Enrichment miss | `email`/`phone` return `found == false` → write `""`, do not crash |
| Empty search | zero results → write an empty file + a clear "0 matched — loosen filters or re-check enums" note |
| Phone, non-US | only call `enrichment.phone` when `country_code == "US"`; else skip |
| Rate limit (429) | handled by the SDK; never hand-roll a `sleep(60)` loop |

## Enrichment order (don't burn credits)
Enrichment is one paid call per record, so spend credits only on keepers. Always:
**search → dedupe on `linkedin_url` → post-hoc ICP cleanup → enrich the survivors.** Never enrich
duplicates or rows you'll discard — the partitioned template dedupes *before* enriching for exactly
this reason. Email is broadly available; **phone is US-only** — gate on `country_code == "US"`, and
only when the user asked for phones.

## Failure to install the SDK
If `scripts/verify_sdk.sh` reports NOT INSTALLED and the install command fails, **stop** and show
the user the exact command (`uv add blitz-api-py` / `bun add blitz-api-js`) and error. Do not fall
back to raw `requests`/`fetch` — a hand-rolled client loses the SDK's pagination, throttling,
retries, and typed enums, which is the whole reason this skill exists.

## Few or zero results — two causes
A hard **0** from a correct-looking search is usually a case-sensitive enum *typo*: re-run
`blitz-gtm-brainstorm`'s `scripts/pull_enums.sh` and confirm every `industry` / `job_function` /
`job_level` / `employee_range` / `type` value matches exactly. A **suspiciously small but non-zero**
count is usually the *sparse-enum* trap — a correctly-spelled `industry`/`job_level` only matches
tagged records. Drop the sparse enum and lean on the `job_title` / `keywords` backbone instead
(see `blitz-gtm-brainstorm/references/strategy.md`).
