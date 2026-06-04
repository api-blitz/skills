# Endpoint decision guide

Pick exactly one search endpoint for the brief. Get this wrong and everything downstream is
wrong. All search endpoints use `POST` and take `max_results` (page size, max 50).

**First read [strategy.md](strategy.md).** Recall-first thinking — build the search from the dense
`job_title` / company `keywords` backbone, treat `industry` / `job_level` as sparse precision knobs
— is usually what decides whether a search returns the real population or a silent fraction of it.

| You have… | You want… | Endpoint | Pagination | Returns |
|-----------|-----------|----------|------------|---------|
| An ICP (industry/size/geo + persona) | Decision-makers across **many** companies | **Find People** `/v2/search/people` | cursor | person fields (flat) + `total_results` |
| A **named account** (1 company) | The single best decision-maker via a priority cascade | **Waterfall ICP** `/v2/search/waterfall-icp-keyword` | none (single set) | `results[].person` + `icp` tier + `ranking` |
| A **named account** (1 company) | **Every** matching employee | **Employee Finder** `/v2/search/employee-finder` | page (`total_pages`) | person fields (flat) |
| An ICP, but you want companies not people | A **company** list | **Company Search** `/v2/search/companies` | cursor | company fields + `total_results` |

Decision shortcuts:
- "Build me a prospect list" / "find leads at companies like X" → **Find People** (collapses
  company search + employee lookup into one call).
- "Break into these 500 accounts" / "who is the buyer at <company>" → **Waterfall ICP** (one
  call per account, returns the best-seniority match).
- "Give me everyone in Sales at <company>" / "how big is X" → **Employee Finder** (enum-only
  filters — no `job_title` keyword; also sizes a company via `total_pages`). For *who to contact*
  at an account, prefer **Waterfall ICP**.
- "Find companies matching this ICP" → **Company Search**, then feed each `linkedin_url` to
  Waterfall / Employee Finder. (For people-by-ICP you don't need to chain — Find People takes the
  same company filters and returns the people directly.)

## Verified request shapes

**Find People** (cursor-based; loop until `cursor` is null):
```json
{
  "company": {
    "industry": { "include": ["Software Development"], "exclude": [] },
    "employee_range": ["51-200", "201-500"],
    "hq": { "country_code": ["US"] },
    "type": { "include": ["Privately Held"] },
    "keywords": { "include": [], "exclude": [] }
  },
  "people": {
    "job_title": { "include": ["Head of Sales", "[VP Sales]"], "exclude": [], "include_linkedin_headline": false },
    "job_level": ["VP", "Director"],
    "job_function": ["Sales & Business Development"],
    "location": { "country_code": ["US"], "sales_region": [], "continent": [], "city": [] },
    "min_connections": 200
  },
  "max_results": 50,
  "cursor": null
}
```
`people.job_title` is a **keyword** match by default — wrap a value in brackets (`"[VP Sales]"`)
for an exact, case/accent-insensitive match. It is full-text, so it's your highest-recall lever:
spray synonyms, long/short forms, and multilingual variants ([strategy.md](strategy.md)).
`people.location` is the **person's** location (distinct from `company.hq`); its keys are
`country_code` / `sales_region` / `continent` / `city` (city is keyword-matched). Company
`keywords.include` searches the company description — prefer it over the sparse `industry` enum.

**Company Search** (cursor-based):
```json
{
  "company": {
    "keywords": { "include": ["SaaS"] },
    "industry": { "include": ["Software Development"] },
    "hq": { "country_code": ["FR", "DE"] },
    "employee_range": ["51-200", "201-500"]
  },
  "max_results": 50,
  "cursor": null
}
```

**Employee Finder** (page-based; increment `page` until `page == total_pages`). Body is flat,
not nested under `company`/`people`:
```json
{
  "company_linkedin_url": "https://www.linkedin.com/company/openai",
  "job_level": ["C-Team", "VP", "Director"],
  "job_function": ["Sales & Business Development"],
  "sales_region": ["NORAM"],
  "max_results": 50,
  "page": 1
}
```

**Waterfall ICP** (priority cascade; the engine fills `max_results` slots top-tier first):
```json
{
  "company_linkedin_url": "https://www.linkedin.com/company/openai",
  "cascade": [
    { "include_title": ["CRO", "VP Sales", "Head of Growth"], "exclude_title": ["intern"], "location": ["US", "GB"], "include_headline_search": false },
    { "include_title": ["Sales Director"], "location": ["WORLD"], "include_headline_search": true }
  ],
  "max_results": 5
}
```
Use `"WORLD"` for a global location. `include_headline_search: true` also matches the person's
headline text (broader, noisier) — turn it on only in lower/fallback tiers. The cascade is a
**priority ranking**, not a seniority ladder: tier 1 = the perfect contact, lower tiers = looser
matches or an alternative persona; the engine fills `max_results` slots top-tier first (5 C-levels
if it can, else it backfills with Directors). Each `results[]` item carries `icp` (which tier
matched, 1 = top) and `ranking` (relevance within the company) — `icp` doubles as a **persona
signal for tailoring outreach copy** (a possibility, not a requirement). See [strategy.md](strategy.md).

## Enrichment (after a search returns LinkedIn URLs)
- `POST /v2/enrichment/email` `{ "person_linkedin_url": "..." }` → `{ found, email }`
- `POST /v2/enrichment/phone` `{ "person_linkedin_url": "..." }` → `{ found, phone }` (US only)
- `POST /v2/enrichment/company` `{ "company_linkedin_url": "..." }` → `{ company: {...} }`
- `POST /v2/enrichment/domain-to-linkedin` `{ "domain": "stripe.com" }` → company LinkedIn URL
  (use this first when you only have a domain and need Waterfall/Employee Finder).
