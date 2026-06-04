# Enum snapshot (offline fallback — NOT the source of truth)

Source: `https://docs.blitz-api.ai/guide/reference/normalization/*`.

**All values are case-sensitive and must match EXACTLY.** A mismatch silently returns 0 results.
Prefer the live pull (`scripts/pull_enums.sh`); use this list only when offline, and re-verify
before any real run. The dataset changes — never treat this snapshot as authoritative.

## Coverage: enums lose results two ways

Case-sensitivity (above) is the *typo → hard 0* failure. The subtler one: a correctly-spelled
`industry`, `job_level`, `job_function`, `type`, or `revenue` only matches records **tagged** with
it — and many companies have no industry linked, many people aren't tagged `VP`. So a clean enum
filter can silently return a *fraction* of the real population (a small but non-zero count).
Treat these enums as **precision knobs**, not the backbone of a search — lead with the dense
`job_title` / company `keywords` fields instead. Full reasoning: [strategy.md](strategy.md).

## job_level (6) — `people.job_level`
`"C-Team"`, `"VP"`, `"Director"`, `"Manager"`, `"Staff"`, `"Other"`

## job_function (22) — `people.job_function`
`"Advertising & Marketing"`, `"Art, Culture and Creative Professionals"`, `"Construction"`,
`"Customer/Client Service"`, `"Education"`, `"Engineering"`, `"Finance & Accounting"`,
`"General Business & Management"`, `"Healthcare & Human Services"`, `"Human Resources"`,
`"Information Technology"`, `"Legal"`, `"Manufacturing & Production"`, `"Operations"`, `"Other"`,
`"Public Administration & Safety"`, `"Purchasing"`, `"Research & Development"`,
`"Sales & Business Development"`, `"Science"`, `"Supply Chain & Logistics"`, `"Writing/Editing"`

## employee_range (8) — `company.employee_range`
`"1-10"`, `"11-50"`, `"51-200"`, `"201-500"`, `"501-1000"`, `"1001-5000"`, `"5001-10000"`, `"10001+"`

## company type (10) — `company.type.include` / `.exclude`
`"Educational"`, `"Educational Institution"`, `"Government Agency"`, `"Nonprofit"`,
`"Partnership"`, `"Privately Held"`, `"Public Company"`, `"Self-Employed"`, `"Self-Owned"`,
`"Sole Proprietorship"`

## sales_region (4) — `people.location.sales_region` / `company.hq.sales_region`
`"NORAM"`, `"LATAM"`, `"EMEA"`, `"APAC"`

## continent (7)
`"Africa"`, `"Antarctica"`, `"Asia"`, `"Europe"`, `"North America"`, `"Oceania"`, `"South America"`

## country_code — ISO 3166-1 alpha-2 (common subset; "WORLD" for Waterfall/Employee Finder global)
`US`, `GB`, `FR`, `CA`, `DE`, `AU`, `NL`, `ES`, `IT`, `IN`, `BR`, `SG`, `SE`, `CH`, `BE`, `DK`,
`NO`, `FI`, `PL`, `IL`, `JP`, `KR`, `CN`, `MX`, `AR`, `CL`, `CO`, `ZA`, `AE`, `SA`

## industry — 534 total; full list ONLY via the live pull
Do not hardcode an industry filter from memory. Common exact values for sanity-checking:
`"Software Development"`, `"IT Services and IT Consulting"`, `"Internet"`, `"Financial Services"`,
`"Banking"`, `"Insurance"`, `"Hospital and Health Care"`, `"Hospitals and Health Care"`,
`"Biotechnology Research"`, `"Pharmaceutical Manufacturing"`, `"Retail"`, `"E-Learning Providers"`,
`"Telecommunications"`, `"Real Estate"`, `"Staffing and Recruiting"`, `"Marketing Services"`,
`"Advertising Services"`, `"Management Consulting"`, `"Venture Capital and Private Equity Principals"`,
`"Manufacturing"`, `"Computer and Network Security"`, `"Data Infrastructure and Analytics"`.

Watch the near-duplicates — pick the exact one the dataset uses, do not guess:
`"Hospital and Health Care"` vs `"Hospitals and Health Care"`; `"Airlines and Aviation"` vs
`"Airlines/Aviation"`; `"E-learning"` vs `"E-Learning Providers"`. When unsure, pull live and grep.
