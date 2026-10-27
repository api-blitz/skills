# Error handling and key safety (baseline for every generated script)

## API-key safety (always)
- Read the key from `BLITZ_API_KEY` (env) and keep it out of source and logs.
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
- The SDK sends the key in the `x-api-key` header. Call Blitz from backend code only; browser and
  mobile bundles expose the key.

## Preflight (fail fast)
Call `account.key_info()` before the run (free — 0 records). Stop early on:
- `valid == false` → bad/rotated key.
- `records_remaining` is `0` or below the planned run (a number, e.g. `5000000`).
  Every search result and every successful enrichment is one record; the allowance resets at
  `next_reset_at`.
- the endpoint you need is not in `allowed_apis` (paths come without the `/v2` prefix), or you
  need phone on the free trial — Find Mobile & Direct Phone is not part of the trial.

Then build the working client with `rate_limit_rps` from the key (`sdk-reference.md` →
Configuration judgment).

## Cases the generated script MUST handle
| Case | How |
|------|-----|
| Bad key (401) | preflight `key_info().valid`; exit with a clear message |
| Allowance reached (402) | preflight `records_remaining`; the SDK raises `InsufficientRecordsError` (Py) / `FairUsageLimitError` (JS) carrying `fair_usage.next_reset_at` — stop and tell the user when the allowance resets, or that they need a bigger plan |
| Invalid request (422) | not retried, no records spent — read `errors[].field`: an unknown/misspelled field, a bad enum value, a list over 50 entries, a range with `min` > `max`, both job flags `false`. Fix the request |
| Enrichment miss | `email`/`phone` return `found == false` → write `""` and continue |
| Empty search | zero results → write an empty file + a clear "0 matched — loosen filters or re-check free-text filters" note |
| Phone, non-US | call `enrichment.phone` only when `country_code == "US"`; skip otherwise (the free trial has no phone either) |
| Rate limit (429) | the SDK retries with backoff (`sdk-reference.md`) |
| Timeout | `APITimeoutError` is **not** retried (the server may already have counted the records) — raise the per-call `timeout` |

## Enrichment order (spend records on keepers)
Enrichment bills one record per successful call (and every search result is a record too), so
spend them only on keepers:
**search → dedupe on `linkedin_url` → post-hoc ICP cleanup → enrich the survivors.** The
partitioned template dedupes *before* enriching for this reason. Email is broadly available;
**phone is US-only and paid-plan only** — call it when the user asked for phones and
`country_code == "US"`.

## Few or zero results — three causes
A hard **0** from a correct-looking search is usually a typo in a *free-text* filter, which the API
does not check: `country_code` (`"USA"` → `"US"`), `city`, `job_title`, `keywords`. A typo in a
categorical enum is loud: the API answers `422` with the field and the closest valid value, so
re-run `blitz-gtm-brainstorm`'s `scripts/pull_enums.sh` to match it exactly. A **suspiciously small
but non-zero** count is usually the *sparse-enum* trap — a correctly spelled `industry`/`job_level`
only matches tagged records — so lean on the `job_title` / `keywords` backbone (the recall-first
guidance in the `blitz-gtm-brainstorm` skill's `strategy.md`, if installed). A third cause is title
phrasing: phrases match whole words with no abbreviation expansion, so `VP` will not find
`Vice President`; list each form.
