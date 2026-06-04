# GTM brief schema (the handoff contract)

The brief is a single YAML file, `gtm-brief.yaml`, written to the user's working directory. It
is the contract between `blitz-gtm-brainstorm` (producer) and `blitz-create-script` (consumer).
It is a **superset**: fill only the keys the chosen `endpoint` uses; leave the rest at defaults.

```yaml
brief_version: 1
goal: "Reach Heads of Sales at US Series-B SaaS companies"   # the user's one-liner
motion: new-business          # new-business | account-penetration | crm-enrichment | market-research
endpoint: find-people         # find-people | waterfall-icp | company-search | employee-finder
language: python              # python | typescript | javascript

# --- Company-level filters (find-people, company-search) ---
account:
  industry_include: ["Software Development", "Internet"]   # exact, case-sensitive enums
  industry_exclude: []
  employee_range: ["51-200", "201-500"]                    # exact buckets, e.g. "51-200"
  hq_country_code: ["US"]                                  # ISO-3166-1 alpha-2; "US" not "USA"
  hq_sales_region: []                                      # NORAM | LATAM | EMEA | APAC
  type_include: []                                         # e.g. "Privately Held", "Public Company"
  keywords_include: []                                     # → company.keywords.include (searches the description; high-recall — prefer over industry)
  keywords_exclude: []

# --- Person-level filters (find-people, employee-finder, waterfall-icp) ---
people:
  job_title_include: ["Head of Sales", "VP Sales"]        # → people.job_title.include (FTS keyword backbone — spray synonyms / long+short / multilingual; wrap "[..]" for exact)
  job_title_exclude: []                                    # → people.job_title.exclude
  job_level: ["C-Team", "VP", "Director"]                  # C-Team|VP|Director|Manager|Staff|Other
  job_function: ["Sales & Business Development"]           # one of the 22 functions
  location_country_code: ["US"]                            # → people.location.country_code (person location, NOT company.hq)
  sales_region: []                                         # → people.location.sales_region
  min_connections: 0

# --- Single-company motions (waterfall-icp, employee-finder) ---
target_company:
  company_linkedin_url: null         # required for waterfall-icp / employee-finder
  company_list_source: null          # path/description of an account list for account-penetration
  cascade: []                        # waterfall tiers (ordered); see endpoint-decision.md

# --- Enrichment ---
enrichment:
  email: true                        # POST /v2/enrichment/email
  phone: false                       # POST /v2/enrichment/phone — US contacts only
  reverse: none                      # none | email-to-person | phone-to-person

# --- Output ---
output:
  target: csv                        # csv | json | stdout
  path: "./leads.csv"
  dedupe_key: linkedin_url           # union/dedupe key for partitioned runs

# --- Volume (from scripts/probe_volume.sh) ---
volume:
  estimate: 0
  probe_method: total_results        # total_results | total_pages | manual
  exceeds_ceiling: false             # true → create-script emits the partitioned template
  partition_plan: []                 # see volume-and-partition.md

# --- Validation provenance ---
enums_verified: false                # set true once every enum value you use is matched live (keyword-only = trivially true)
enums_source: "live-pull"            # live-pull | snapshot-fallback
```

## Contract rules (enforced by both skills)

- **`enums_verified` must be `true`** before `blitz-create-script` generates anything. It means
  *every enum value the brief actually uses* has been matched live (a keyword-only search that uses
  no enums is trivially `true`). This guards typo'd case-sensitive enums that silently return 0
  results — it does **not** imply a search should be enum-driven; the recall backbone is keywords
  (see [strategy.md](strategy.md)).
- **If `volume.exceeds_ceiling` is `true`**, create-script MUST emit the partitioned template
  (segment → paginate → union → dedupe by `output.dedupe_key`), not the simple loop.
- **Only keys relevant to `endpoint` need values.** create-script branches on `endpoint` and
  ignores irrelevant keys, so an unused `cascade: []` or `target_company` is fine.
- **`brief_version`** lets the schema evolve without breaking older briefs.
- The API key is **never** in the brief — it stays in `BLITZ_API_KEY` / `.env`.
