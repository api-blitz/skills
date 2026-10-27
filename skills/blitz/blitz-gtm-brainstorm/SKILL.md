---
name: blitz-gtm-brainstorm
description: Scope a Blitz API search into a validated gtm-brief.yaml (endpoint, ICP filters, enrichment, volume). Use when the user wants a lead list, a target-account or hiring-signal list, an ICP definition, or a plan before writing Blitz code.
---

# Blitz GTM Brainstorm

Turn a fuzzy GTM goal into a validated **GTM brief** (`gtm-brief.yaml`), the spec that
`blitz-create-script` compiles into a runnable script. Blitz returns verified B2B people,
companies and job postings.

## Quick start

Ask for the goal in one sentence ("reach Heads of Sales at US Series-B SaaS"), work the steps
below, and emit the brief; code belongs to `blitz-create-script`. A brief excerpt (full schema in
[references/gtm-brief-schema.md](references/gtm-brief-schema.md)):

```yaml
goal: "Reach Heads of Sales at US SaaS companies"
endpoint: find-people
account: { keywords_include: ["SaaS"], employee_range: ["51-200", "201-500"] }
people: { job_title_include: ["Head of Sales", "VP Sales"], location_country_code: ["US"] }
volume: { estimate: 18342, exceeds_ceiling: false }
enums_verified: true
```

`scripts/` and `references/` paths below are relative to this skill's own directory — run the
helpers from there (e.g. `bash <skill-dir>/scripts/pull_enums.sh list`), not the user's project root.

## Workflow

1. **Pick the endpoint.** Match the user's starting point to exactly one endpoint; the table, the
   per-endpoint notes and the chaining advice are in
   [references/endpoint-decision.md](references/endpoint-decision.md).
   - An ICP, people across many companies → **Find People**
   - A named account, its best decision-maker → **Waterfall ICP**
   - A named account, every matching employee → **Employee Finder**
   - Companies rather than people → **Company Search**
   - Accounts from a signal → **TAM by People** (who already works there) or **TAM by Jobs** (who is hiring)
   - The postings themselves → **Job Search** (`/v2/jobs/company` for one company)

   Done when `endpoint` is set and the user's starting point (ICP, named account, or signal)
   explains the choice.

2. **Draft the filters, recall-first.** Read [references/strategy.md](references/strategy.md), then
   build the backbone from the **dense** fields nearly every record has: `job_title` (full-text, so
   spray synonyms, long and short forms, multilingual variants), company `keywords` (searches the
   description), city, headcount, `min_connections`. Add **sparse** enums (`industry`,
   `job_level`, `job_function`, `type`, `revenue`) as precision knobs, because each one can shrink
   the result to tagged-only records. Fill only the keys the chosen endpoint uses.

   Done when every filter belongs to the chosen endpoint and every sparse enum has a stated
   precision reason.

3. **Verify every enum value, live.** Enums are case-sensitive and exact-match (`"SaaS"` ≠
   `"Software Development"`). For each `industry` / `job_level` / `job_function` /
   `employee_range` / `sales_region` / `type` / `last_funding_type` / `mx.provider` value (and, on
   the job endpoints, `seniority` / `employment_type` / `work_arrangement`), run
   `bash scripts/pull_enums.sh search <enum> "<value>"` until the output shows an EXACT match, and
   resolve any miss with the user. `list` shows every enum and `get <enum>` dumps the small ones.
   Free-text filters (`country_code`, `job_title`, `keywords`, `city`) have no list to check
   against, so write `country_code` as ISO alpha-2 (`US`).

   Done when every enum value in the brief matches exactly; set `enums_verified: true` (a
   keyword-only brief uses no enums and counts as verified).

4. **Probe volume, decide partitioning.** Run
   `echo '<request-json>' | BLITZ_API_KEY=... bash scripts/probe_volume.sh /v2/search/people` and
   read `total_results` (Find People, Company Search, job searches) or `total_pages` (Employee
   Finder). Re-probe as you add title/keyword variants until the count saturates or reaches the
   user's target. Past the reachable ceiling (~50k people or companies, ~10k per company, ~5k
   jobs) set `volume.exceeds_ceiling: true` and a `partition_plan`. The TAM endpoints return no
   total, so page their cursor to size them (`probe_method: manual`). Each probe spends one
   record. Mechanics: [references/volume-and-partition.md](references/volume-and-partition.md).

   Done when `volume.estimate` rests on a probe (or `manual` for TAM) and `exceeds_ceiling` is decided.

5. **Enrichment, output, language.** `email` (any plan), `phone` (US-only, paid plans; warn when
   the targets are outside the US or the key is on the free trial), reverse lookups. Every search
   result and successful enrichment bills 1 record against the plan's monthly allowance, so size
   the run against `records_remaining`. Output: `csv` / `json` / `stdout`. Language: `python`,
   `typescript`, or `javascript`, recorded exactly as the user states it.

   Done when the `enrichment`, `output` and `language` blocks are filled and the user has seen the
   run's record estimate (search results plus enrichments).

6. **Emit the brief.** Write `gtm-brief.yaml` per
   [references/gtm-brief-schema.md](references/gtm-brief-schema.md), offer to save it in the
   user's working directory, and tell the user to run **blitz-create-script**.

   Done when the brief is written (or shown) and the handoff is stated.

## Rules

- The references are a working snapshot. Where they disagree with the live schema (the MCP tool's
  input schema or the public OpenAPI) or with `util_changelog`, the live sources win.
- The API key lives in `BLITZ_API_KEY` / `.env`, outside the brief.
- A user who already knows their ICP skips to step 3.
