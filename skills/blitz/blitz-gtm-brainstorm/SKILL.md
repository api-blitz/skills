---
name: blitz-gtm-brainstorm
description: Interviews the user about a go-to-market goal and produces a validated GTM brief: the motion, the Blitz endpoint choice (Find People, Waterfall ICP, Company Search, or Employee Finder), an ICP/account definition with case-sensitive enum-validated filters, an enrichment plan (email/phone), an output target, the language, and a volume estimate. Use when the user wants to find leads, build a prospect or account list, define an ICP, plan outreach sourcing, or scope a Blitz API search before writing code, or says "who should I target", "build me a lead list", or "plan a GTM motion". Produces gtm-brief.yaml and hands off to blitz-create-script.
---

# Blitz GTM Brainstorm

Turn a fuzzy GTM goal into a precise, validated **GTM brief** (`gtm-brief.yaml`) that
`blitz-create-script` compiles into a runnable script with no silent failures. Blitz returns
verified B2B decision-makers from a 380M+ LinkedIn-based dataset; the brief is the spec.

## Quick start

Ask the user for their goal in one sentence ("reach Heads of Sales at US Series-B SaaS"), then
work the steps below and output `gtm-brief.yaml`. Do not write code here — that is
`blitz-create-script`'s job.

`scripts/` and `references/` paths below are relative to this skill's own directory — run the
helpers from there (e.g. `bash <skill-dir>/scripts/pull_enums.sh list`), not the user's project root.

## Workflow

1. **Pick the motion and the endpoint.** Map the goal to exactly one endpoint. Details and
   request shapes: [references/endpoint-decision.md](references/endpoint-decision.md).
   - Many companies, by ICP → **Find People** (`/v2/search/people`)
   - One named account, best decision-maker → **Waterfall ICP** (`/v2/search/waterfall-icp-keyword`)
   - Every person at one company → **Employee Finder** (`/v2/search/employee-finder`)
   - Companies, not people → **Company Search** (`/v2/search/companies`)

2. **Draft the filters — recall-first.** Read [references/strategy.md](references/strategy.md)
   first, then build the backbone from the **dense** fields nearly every record has: `job_title`
   (full-text — spray synonyms, long/short forms, multilingual variants), company `keywords`
   (searches the description), city, headcount, `min_connections`. Add the **sparse** enums
   (`industry`, `job_level`, `job_function`, `type`, `revenue`) only as precision knobs — each can
   silently shrink the result to tagged-only records. Only fill the keys the chosen endpoint uses.

3. **Validate every enum you *do* use — live.** Case-sensitive enums silently return 0 results on
   any typo (`"SaaS"` ≠ `"Software Development"`). For each `industry` / `job_level` /
   `job_function` / `employee_range` / `sales_region` / `country_code` / `type` value in the brief,
   confirm an EXACT match with `bash scripts/pull_enums.sh search <enum> "<value>"` (e.g.
   `search industry "health"`; `list` shows all enums, `get <enum>` dumps the small ones). Fix any
   miss with the user. The script pulls live from the Blitz OpenAPI spec — the same source the SDK
   generates its enums from; if offline it falls back to the committed
   [references/enums.json](references/enums.json) (may be stale — re-verify). Set
   `enums_verified: true` once the enums you use all match (a keyword-only search that uses no enums
   is trivially verified). This guards typos — it is **not** a nudge to lean on enums; prefer the
   keyword backbone from step 2.

4. **Probe volume, decide partitioning.** Run
   `echo '<request-json>' | BLITZ_API_KEY=... bash scripts/probe_volume.sh /v2/search/people`
   to read `total_results` (Find People / Company Search) or `total_pages` (Employee Finder). If
   the population exceeds the reachable ceiling (~50k people/companies, ~10k per company), set
   `volume.exceeds_ceiling: true` and a `partition_plan`. See
   [references/volume-and-partition.md](references/volume-and-partition.md).

5. **Enrichment, output, language.** `email` (any leads plan), `phone` (US-only — warn if the
   targets are not US), reverse lookups. Output: `csv` / `json` / `stdout`. Language: `python`,
   `typescript`, or `javascript` — record the user's choice as-is (don't default a JS user to TS).

6. **Emit the brief.** Write `gtm-brief.yaml` per
   [references/gtm-brief-schema.md](references/gtm-brief-schema.md) and offer to save it in the
   user's working directory. Then tell the user to run **blitz-create-script**.

## Rules

- Never guess an enum value you use. Pull live and match exactly, on every run (the dataset
  changes) — but prefer the dense keyword backbone, so you depend on enums as little as possible.
- Never put the API key in the brief. It lives in `BLITZ_API_KEY` / `.env` only.
- If the user already knows their ICP, skip ahead — but still validate enums (step 3).
