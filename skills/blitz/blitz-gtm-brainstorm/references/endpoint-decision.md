# Endpoint decision guide

Pick exactly one search endpoint for the brief. All search endpoints use `POST` and take
`max_results`, a page size (max 50; Waterfall ICP up to 100; the MCP tools cap it lower, so read the
tool's own schema). Every `/v2` endpoint **rejects a field it does not define with a `422`** (at any
depth, no records spent), so send only keys that exist in the live schema; `null` reads as "omitted".

This file is a decision aid, not the spec. Read an exact body from the public OpenAPI (no key
needed) or from the MCP tool's input schema:

```bash
mkdir -p /tmp/blitz-spec && curl -s https://api.blitz-api.ai/openapi -o /tmp/blitz-spec/openapi.json
jq '.paths["/v2/search/people"].post.requestBody.content["application/json"].schema' /tmp/blitz-spec/openapi.json
```

The copy `docs_read` serves under `/openapi/` can lag both.

| You have… | You want… | Endpoint | Pagination | Returns |
|-----------|-----------|----------|------------|---------|
| An ICP (industry/size/geo + persona) | Decision-makers across **many** companies | **Find People** `/v2/search/people` | cursor | person fields (flat) + `total_results` |
| A **named account** (1 company) | The single best decision-maker via a priority cascade | **Waterfall ICP** `/v2/search/waterfall-icp-keyword` | none (single set) | `results[].person` + `icp` tier + `ranking` |
| A **named account** (1 company) | **Every** matching employee | **Employee Finder** `/v2/search/employee-finder` | page (`total_pages`) | person fields (flat) |
| An ICP, but you want companies not people | A **company** list | **Company Search** `/v2/search/companies` | cursor | company fields + `total_results` |
| A buyer persona (who works there) | The **accounts** that employ it | **TAM by People** `/v2/company/tam-by-people` | cursor (no total) | `results[].company` + `matched_people` |
| A hiring signal (what they recruit for) | The **accounts** hiring for a role | **TAM by Jobs** `/v2/company/tam-by-jobs` | cursor (no total) | `results[].company` + `matched_jobs` |
| A hiring signal | The **job postings** themselves | **Job Search** `/v2/jobs/search` (market) or `/v2/jobs/company` (one company) | cursor | postings + `total_results` |

## Starting points

- "Build me a prospect list" / "find leads at companies like X" → **Find People** (one call replaces
  company search plus employee lookup).
- "Break into these 500 accounts" / "who is the buyer at <company>" → **Waterfall ICP**, one call
  per account.
- "Everyone in Sales at <company>" / "how big is X" → **Employee Finder** (it also sizes a company
  through `total_pages`). For *who to contact* at an account, prefer Waterfall ICP.
- "Find companies matching this ICP" → **Company Search**, then feed each `linkedin_url` to
  Waterfall ICP or Employee Finder. People-by-ICP needs no chaining: Find People takes the same
  company filters.
- "Which accounts are hiring SDRs?" → **TAM by Jobs** (intent). "Which accounts already employ a
  RevOps team?" → **TAM by People** (persona fit). Both feed the named-account motions the way
  Company Search does.
- "What is this company hiring for?" → **Job Search by company**.
- Only a domain in hand? Run `enrichment/domain-to-linkedin` first; Waterfall ICP and Employee
  Finder take a LinkedIn company URL.

## Per-endpoint notes (what the schema doesn't tell you)

**Find People** (nested `company` + `people` blocks, cursor-paged).
- `people.job_title` is a keyword match; wrap a value in brackets (`"[VP Sales]"`) for an exact,
  case/accent-insensitive match. It is the highest-recall lever (`strategy.md`).
- `people.location` is the *person's* location, distinct from `company.hq`; `city` is keyword-matched.
- Company `keywords.include` searches the description, so it beats the sparse `industry` enum.
- Signal levers on the same body: `people.include_past_jobs` (a job held *before*),
  `people.is_recent_hire` (matching job started in the last 90 days), `people.job_description`
  (phrases in the matched job's description), `people.education`, and `company.mx.provider`
  (mail provider).

**Company Search** (cursor-paged). The `company` block of Find People plus revenue, funding,
traffic and NAICS/SIC; read the live schema for the full list.

**Employee Finder** (page-paged until `page == total_pages`). The body is flat
(`company_linkedin_url`, `job_level`, `job_function`, `sales_region`, `min_connections_count`,
`page`), `country_code` defaults to `["WORLD"]`, and the filters are enum-only (no `job_title`
keyword).

**Waterfall ICP** (one ranked set, no pagination).
- The cascade is a **priority ranking**, not a seniority ladder: tier 1 is the perfect contact,
  lower tiers are looser matches or an alternative persona, and the engine fills `max_results`
  slots top tier first (5 C-levels if it can, else it backfills with Directors).
- Each `results[]` item carries `person`, `icp` (the tier that matched, 1 = top) and `ranking`
  (relevance within the company). `icp` doubles as a persona signal for tailoring outreach copy.
- `include_headline_search: true` also matches the person's headline (broader, noisier), so it
  belongs in the lower, fallback tiers.
- Per-tier switches `include_past_jobs` and `is_recent_hire` work as in Find People; both job
  flags `false` in one tier is a `422`.
- A cascade holds 1–10 tiers and each title list up to 50 phrases. A tier's `location` is a list of
  country codes (`"WORLD"` or empty = global) or an object (`city` / `country_code` / `continent` /
  `sales_region`, each list up to 10 values). The SDK types may accept only the list, which always
  works.

**TAM by People, TAM by Jobs, Job Search.**
- TAM by People takes the Find People body (minus the past/active job flags) and returns *distinct
  companies* with `matched_people`; `people.min_per_company` (max 25) floors it.
- TAM by Jobs takes a `job` block (title, description, field, seniority, employment type, work
  arrangement, location, `date_posted.last_days`) plus a `company` block and returns companies with
  `matched_jobs`; `job.min_per_company` (max 25) floors it. `job.seniority` is a *years-of-experience*
  band (`0-2` … `10+`), unrelated to `job_level`.
- Job Search returns the postings: `/v2/jobs/search` takes the same `job` and `company` blocks as
  TAM by Jobs, and `/v2/jobs/company` takes a `company_linkedin_url` plus the `job` block.
- **Job Search and TAM by Jobs use different shapes than people/company search.** `company.hq.country_code`
  and `job.location.country_code` are `{include, exclude}` objects (people/company search take
  plain lists), and `company.size` is `{include: [...]}`, the name for employee-range bands.
- No TAM endpoint returns a total, and a `min_per_company` floor can make a page short, so page
  until the cursor is null. TAM by Jobs' default `max_results` differs between the REST spec and
  the MCP tool; set it explicitly.

## Enrichment (after a search returns LinkedIn URLs)

Each call bills 1 record on success; a miss returns `found: false` and bills nothing.
- `enrichment/email` → `found`, `email`. `enrichment/phone` → `found`, `phone`: **US only, and not
  on the free trial**.
- `enrichment/person`: the full profile (career, education, skills).
- `enrichment/email-to-person` / `phone-to-person`: reverse lookups returning `found`, `person`;
  `phone-to-person` takes **US numbers only**.
- `enrichment/company`; `enrichment/domain-to-linkedin` and `linkedin-to-domain` convert between a
  domain and a company LinkedIn URL.
- `enrichment/company-distribution-by-country` / `-by-department`: headcount split, handy for
  sizing an account before an Employee Finder pull.
