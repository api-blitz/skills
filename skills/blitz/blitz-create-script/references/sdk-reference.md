# Blitz SDK reference (how to generate against it)

The SDKs are documented live in the Blitz docs: `/sdks/overview`, `/sdks/python`, `/sdks/typescript`,
`/sdks/pagination`, `/sdks/rate-limits`. With the Blitz MCP connected, read them there
(`docs_read` → `cat /sdks/python.mdx`); without it, https://docs.blitz-api.ai/sdks/overview (append
`.md` for plain text). Read the page for the method you are about to emit and take names from it,
not from memory.

This file keeps only what stays true across releases: the shape of the surface, and the judgment
calls. Verify the installed version with `scripts/verify_sdk.sh`, and confirm a name with
`help(...)` (Python) or the package's `.d.ts` (JS).

## Install and construct

```python
# uv add blitz-api-py   (or pip install blitz-api-py)      # Python 3.10+
from blitz_api import BlitzAPI            # AsyncBlitzAPI for async
client = BlitzAPI()                       # reads BLITZ_API_KEY; BlitzAPI(api_key="sk_...") is explicit
```
```ts
// bun add blitz-api-js   (or npm install blitz-api-js)    // Node 20+
import { BlitzAPI } from "blitz-api-js";  // CJS: const { BlitzAPI } = require("blitz-api-js")
const client = new BlitzAPI();            // reads BLITZ_API_KEY
```

## The surface

- Seven namespaces: `account`, `search`, `jobs`, `company`, `enrichment`, `utils`, `changelog`.
  A method mirrors the REST path: the group is the namespace and the last segment, in snake_case,
  is the method (`POST /v2/company/tam-by-jobs` → `client.company.tam_by_jobs`), occasionally
  shortened (`/v2/search/waterfall-icp-keyword` → `client.search.waterfall_icp`).
- Option keys are the REST body keys, 1:1 and snake_case. Python takes them as kwargs, JS as one
  options object. The server rejects a key it does not define with a `422`, so use only options
  from the schema.
- Enum-backed fields take the typed enum (`from blitz_api.types import Industry, JobLevel`; JS
  string unions / `INDUSTRY`) **or** a raw string.
- Every metered response carries `fair_usage` (`records_used`, `records_remaining`, `next_reset_at`,
  `request_id`, and `rate_limit.remaining_this_second` when present) — read it instead of calling
  `key_info` between requests.

## Pagination

List methods return an auto-paginating page. Prefer streaming over a manual cursor loop:

```python
for person in client.search.people(company={...}, people={...}).auto_paging_iter(max_items=500):
    ...
page = client.search.people(..., max_results=50)        # manual: page.results, page.total_results
nxt = page.get_next_page()                              # None when exhausted
```
```ts
for await (const person of client.search.people({ company: {...}, people: {...}, max_items: 500 })) { ... }
const first = await client.search.people({ ..., max_results: 50 });   // first.data, first.response.total_results
const more = first.has_next_page() ? await first.get_next_page() : null;
```

- `max_results` is the **page size**, not a total. A bare loop streams every match up to the
  server-side ceiling, and each result returned is a billed record — bound it with `max_items` (a
  client-side cap, never sent on the wire) or `break`.
- Which methods paginate: the searches, the job searches and the TAM methods (cursor), and Employee
  Finder (page number). Waterfall ICP returns one ranked set; enrichment, `utils`, `account` and
  `changelog` return a single response.
- `total_results` exists on the people, company and job searches — **not** on the TAM methods.

## Configuration judgment

- `rate_limit_rps` throttles client-side and defaults to 5. The API limit is **per endpoint** and the
  SDK keeps one bucket per endpoint path, so one client per process already runs `/enrichment/email`
  and `/enrichment/phone` each at its own limit. Set `rate_limit_rps` to the key's
  `max_requests_per_seconds`, read from `account.key_info()` (a number, e.g. `25`). The limiter
  lives on the client instance, so divide `rate_limit_rps` between workers that share an endpoint
  (5 workers on a 10 rps key → 2 each); workers on different endpoints don't compete.
- Keep `max_retries` at its default: `429` and `5xx` are retried with backoff. A read timeout is
  **not** retried (the server may already have counted the records), so raise the per-call `timeout`.
- Errors: `401` authentication, `402` allowance reached (carries `fair_usage.next_reset_at`), `404`,
  `429`, `5xx`, timeouts, connection and response-validation errors each have a class. A `400`/`422`
  surfaces as the generic status error — `err.body["errors"]` (JS: `err.body.errors`) lists
  `{field, message}`. **Import the class names from the installed package** — the allowance error
  has been renamed between releases, so `help(blitz_api)` / the `.d.ts` beats memory.

## Where the SDK types can lag the API

The REST API sometimes accepts a body shape before the SDK's types list it, and the server's `422`
(`errors[].field`) is the arbiter. Before relying on a newly announced filter, check the live schema
(the public spec, `curl -s https://api.blitz-api.ai/openapi`; the copy `docs_read` serves under
`/openapi/` can lag it) and the installed SDK's types, and prefer the shape both agree on. For
waterfall `cascade[].location`, the list of country codes is the safe form.

## Account / preflight

`client.account.key_info()` (`GET /v2/account/key-info`, free) returns `valid`, `id`,
`records_remaining` (a number, e.g. `5000000`), `next_reset_at`,
`max_requests_per_seconds` (per endpoint), `allowed_apis` (paths without the `/v2` prefix) and
`active_plans`. Use it as a preflight: fail fast on a bad key, an exhausted allowance, or an
endpoint the plan lacks.
