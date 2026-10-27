# GTM brief schema (the handoff contract)

The brief is a single YAML file, `gtm-brief.yaml`, written to the user's working directory. It
is the contract between `blitz-gtm-brainstorm` (producer) and `blitz-create-script` (consumer).
It is a **superset**: fill only the keys the chosen `endpoint` uses; leave the rest at defaults.

```yaml
brief_version: 1
goal: "Reach Heads of Sales at US Series-B SaaS companies"   # the user's one-liner
motion: new-business          # new-business | account-penetration | crm-enrichment | market-research | hiring-signal
endpoint: find-people         # find-people | waterfall-icp | company-search | employee-finder
                              #   | tam-by-people | tam-by-jobs | job-search | company-jobs
language: python              # python | typescript | javascript

# --- Company-level filters (find-people, company-search, tam-by-people) ---
account:
  industry_include: ["Software Development", "Internet"]   # exact, case-sensitive enums
  industry_exclude: []
  employee_range: ["51-200", "201-500"]                    # exact buckets, e.g. "51-200"
  hq_country_code: ["US"]                                  # → company.hq.country_code; ISO-3166-1 alpha-2, "US" not "USA"
  hq_sales_region: []                                      # NORAM | LATAM | EMEA | APAC
  type_include: []                                         # e.g. "Privately Held", "Public Company"
  keywords_include: []                                     # → company.keywords.include (searches the description; high-recall — prefer over industry)
  keywords_exclude: []

# --- Person-level filters (find-people, employee-finder, waterfall-icp, tam-by-people) ---
people:
  job_title_include: ["Head of Sales", "VP Sales"]        # → people.job_title.include (FTS keyword backbone — spray synonyms / long+short / multilingual; wrap "[..]" for exact)
  job_title_exclude: []                                    # → people.job_title.exclude
  job_description_include: []                              # → people.job_description.include (find-people / tam-by-people: phrases in the matched job's description; SDK types may not list it yet)
  job_level: ["C-Team", "VP", "Director"]                  # C-Team|VP|Director|Manager|Staff|Other
  job_function: ["Sales & Business Development"]           # one of the 22 functions
  location_country_code: ["US"]                            # → people.location.country_code (person location, NOT company.hq)
  sales_region: []                                         # → people.location.sales_region
  min_connections: 0
  is_recent_hire: false                                    # only people whose matching job started in the last 90 days
  include_past_jobs: false                                 # find-people / waterfall-icp tiers: also match jobs held before
  min_per_company: 0                                       # tam-by-people only (max 25): floor on matching people per company

# --- Job filters (tam-by-jobs, job-search, company-jobs) ---
# The `account` filters above also feed the `company` block of tam-by-jobs and job-search (industry,
# hq, keywords, headcount); company-jobs takes only `company_linkedin_url` plus `jobs`. The wire
# shapes differ there: employee-range bands are `company.size` as `{include: [...]}`, and
# `hq.country_code` is `{include, exclude}`, not a list.
jobs:
  title_include: []                  # → job.title.include (keyword; "[..]" for exact)
  title_exclude: []
  description_include: []            # → job.description.include
  seniority: []                      # years-of-experience bands: 0-2 | 2-5 | 5-10 | 10+ (NOT job_level)
  employment_type: []                # FULL_TIME | PART_TIME | CONTRACTOR | TEMPORARY | INTERN | ...
  work_arrangement: []               # On-site | Hybrid | Remote OK | Remote Solely
  location_country_code: []          # → job.location.country_code.include (the JOB's location, not the company HQ)
  date_posted_last_days: 30          # → job.date_posted.last_days
  min_per_company: 0                 # tam-by-jobs only (max 25): floor on matching postings per company

# --- Single-company motions (waterfall-icp, employee-finder, company-jobs) ---
target_company:
  company_linkedin_url: null         # required for waterfall-icp / employee-finder / company-jobs
  company_list_source: null          # path/description of an account list for account-penetration
  cascade: []                        # waterfall tiers (ordered); see endpoint-decision.md

# --- Enrichment ---
enrichment:
  email: true                        # POST /v2/enrichment/email
  phone: false                       # POST /v2/enrichment/phone — US contacts only, paid plan
  reverse: none                      # none | email-to-person | phone-to-person (phone-to-person: US numbers only)

# --- Output ---
output:
  target: csv                        # csv | json | stdout
  path: "./leads.csv"
  dedupe_key: linkedin_url           # union/dedupe key for partitioned runs

# --- Volume (from scripts/probe_volume.sh) ---
volume:
  estimate: 0
  probe_method: total_results        # total_results | total_pages | manual (tam-by-* has no total)
  exceeds_ceiling: false             # true → create-script emits the partitioned template
  partition_plan: []                 # see volume-and-partition.md

# --- Validation provenance ---
enums_verified: false                # set true once every enum value you use is matched live (keyword-only = trivially true)
```

## Contract rules (enforced by both skills)

- **`enums_verified` must be `true`** before `blitz-create-script` generates anything: every enum
  value the brief uses has been matched live. It guards typo'd case-sensitive enums (a `422`
  mid-run); the recall backbone stays keyword-first (`strategy.md`).
- **If `volume.exceeds_ceiling` is `true`**, create-script MUST emit the partitioned template
  (segment → paginate → union → dedupe by `output.dedupe_key`), not the simple loop.
- **Only keys relevant to `endpoint` need values.** create-script branches on `endpoint` and
  ignores irrelevant keys, so an unused `cascade: []` or `target_company` is fine.
- **`brief_version`** lets the schema evolve without breaking older briefs.
- The API key lives in `BLITZ_API_KEY` / `.env`, outside the brief.
