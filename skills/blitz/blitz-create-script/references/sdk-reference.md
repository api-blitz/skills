# Blitz SDK reference (the surface to generate against)

The docs site does **not** document the SDKs, so this file is the surface. Verify the installed
version with `scripts/verify_sdk.sh`; if the SDK has moved on, confirm method names with
`help(...)` (Python) or the package's `.d.ts` (JS). Method option keys mirror the REST body 1:1
(snake_case).

## Python — `blitz-api-py` (Python 3.10+)

Install: `uv add blitz-api-py`  (or `pip install blitz-api-py`)

```python
from blitz_api import BlitzAPI          # AsyncBlitzAPI for async
client = BlitzAPI()                     # reads BLITZ_API_KEY; or BlitzAPI(api_key="sk_...")
# Tuning (the SDK already throttles + retries — keep these unless told otherwise):
# BlitzAPI(max_retries=3, rate_limit_rps=5.0)   # rate_limit_rps=None to disable
```

Enums (optional; raw strings also accepted):
```python
from blitz_api.types import Industry, JobLevel   # e.g. JobLevel.VP or just "VP"
```

Methods (kwargs mirror the request body in `endpoint-decision.md`):
```python
client.search.people(company={...}, people={...}, max_results=50)
client.search.companies(company={...}, max_results=50)
client.search.employee_finder(company_linkedin_url="...", job_level=[...],
                              job_function=[...], sales_region=[...], max_results=50)
client.search.waterfall_icp(company_linkedin_url="...", cascade=[...], max_results=5)
client.enrichment.email(person_linkedin_url="...")     # -> .found, .email
client.enrichment.phone(person_linkedin_url="...")     # -> .found, .phone  (US only)
client.enrichment.company(company_linkedin_url="...")  # -> .company
```

Pagination (prefer auto):
```python
# Stream ALL results across pages (Find People, Company Search, Employee Finder):
for person in client.search.people(company={...}, people={...}):
    ...
# Bound the total fetched:
for person in client.search.people(...).auto_paging_iter(max_items=500):
    ...
# Manual control:
page = client.search.people(..., max_results=50)
page.results        # list on this page
page.total_results  # population size (Find People / Company Search)
nxt = page.get_next_page()   # None when exhausted
# Page-by-page:
for page in client.search.companies(...).iter_pages():
    page.total_results, page.results, page.cursor
```
Waterfall ICP returns a single ranked set (no pagination); each item has `.person`, `.icp`
(tier matched), `.ranking`.

## TypeScript / JavaScript — `blitz-api-js` (Node 20+; runs under bun)

Install: `bun add blitz-api-js`  (or `npm install blitz-api-js`)

```ts
import { BlitzAPI } from "blitz-api-js";          // CJS: const { BlitzAPI } = require("blitz-api-js")
const client = new BlitzAPI();                    // reads BLITZ_API_KEY
// const client = new BlitzAPI({ api_key: "sk_...", max_retries: 3, rate_limit_rps: 5, timeout: 30 });
```

Filters accept string unions (`"Software Development"`, `"VP"`). Optional helpers:
```ts
import { INDUSTRY } from "blitz-api-js";           // the full 534-value array
import type { Industry, CompanyFilter } from "blitz-api-js";
```

Methods (options are snake_case, 1:1 with the REST body):
```ts
client.search.people({ company: {...}, people: {...}, max_results: 50 })   // PagePromise
client.search.companies({ company: {...}, max_results: 50 })               // PagePromise
client.search.employee_finder({ company_linkedin_url: "...", max_results: 50 }) // page-paginated
client.search.waterfall_icp({ company_linkedin_url: "...", cascade: [...], max_results: 5 }) // single set
client.enrichment.email({ person_linkedin_url: "..." })    // -> { found, email }
client.enrichment.phone({ person_linkedin_url: "..." })    // -> { found, phone }  (US only)
client.enrichment.company({ company_linkedin_url: "..." }) // -> { company }
```

Pagination (prefer `for await`):
```ts
// Stream ALL results:
for await (const person of client.search.people({ company: {...}, people: {...} })) { ... }
// Collect into an array, capped:
const people = await client.search.people({ ..., max_items: 500 }).collect();
// First page + totals:
const first = await client.search.people({ ..., max_results: 50 });
first.response.total_results;   // population size
first.data;                     // items on this page
first.has_next_page();          // boolean
const next = await first.get_next_page();
```
`max_results` = page size (1–50). `max_items` = client-side cap on total fetched.

## Account / preflight
```
POST /v2/account/key-info  ->  { valid, remaining_credits, max_requests_per_seconds, allowed_apis }
```
Python: `client.account.key_info()` · JS: `client.account.key_info()` (mirrors the endpoint). Use
it as a preflight to fail fast on a bad key, an exhausted plan, or an endpoint the plan lacks.
