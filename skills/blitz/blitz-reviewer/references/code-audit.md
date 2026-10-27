# Auditing the user's Blitz code — find the calls, then read the live schema

Checks 4–5 of the checklist (`checklist.md`). The flow is: **find every Blitz call site** (grep —
deterministic), then **validate each against the live schema** (endpoints, request bodies, enum
values). The real surface changes (new enrichment endpoints, renamed fields, added enum values), and
a stale assumption is exactly the bug this skill exists to catch.

## 1. Find the call sites (grep)

Scan the project (skip `node_modules`, `.venv`, `dist`, `.git`). Useful patterns:

```
BlitzAPI|AsyncBlitzAPI|blitz_api|blitz-api-js          # imports / client construction
\.search\.|\.enrichment\.|\.account\.|\.jobs\.|\.company\.   # SDK method calls
api\.blitz-api\.ai|requests\.|httpx\.|fetch\(|axios    # raw-HTTP anti-pattern
BLITZ_API_KEY|sk_[A-Za-z0-9]{8}                        # key handling (and hardcoded keys)
rate_limit_rps                                          # for the RPS check (key-and-rps.md)
remaining_credits|InsufficientCreditsError|x-credit-    # removed names — the full list is in migration-notes.md
field_of_study|profile_picture_url
```

Record `file:line` for every hit — findings need a location. The SDK methods mirror the REST paths
1:1 (`client.search.people` → `POST /v2/search/people`, `client.enrichment.email` →
`POST /v2/enrichment/email`, `client.account.key_info` → `GET /v2/account/key-info`), and option
keys are snake_case, identical to the request body. Resolve the exact path from the live spec.

## 2. Read the live surface

Sources, freshest first:

1. **The MCP tool's input schema.** It is already in your tool list (for example `people_search`),
   and reading it costs nothing.
2. **The public OpenAPI** — no key, no records:
   ```bash
   mkdir -p /tmp/blitz-spec && curl -s https://api.blitz-api.ai/openapi -o /tmp/blitz-spec/openapi.json
   jq -r '.paths | keys[]' /tmp/blitz-spec/openapi.json        # real endpoints: does this method map to a path?
   jq '.paths["/v2/search/people"].post.requestBody.content["application/json"].schema' \
     /tmp/blitz-spec/openapi.json                              # keys, types, required, nesting
   ```
3. **`util_changelog`** (optionally `days`), or `GET https://api.blitz-api.ai/changelog` without
   the MCP. Breaking changes (a renamed field, a new `422`, a lowered cap) land here before the
   docs pages, so the changelog is the newest word.
4. **The docs**, through `docs_search` (semantic — best for "how does X work") and `docs_read` (a
   read-only `rg`/`cat`/`jq`/`tree` shell over the docs and specs; an older docs-only Blitz MCP
   names these `search_…` and `query_docs_filesystem_…`):
   ```bash
   ls /guide/reference/normalization/        # job-levels, industries, companies, geography, filters, urls
   cat /guide/reference/normalization/job-levels.mdx
   rg -i "software development" /guide/reference/normalization/industries.mdx
   cat /api-reference/people-search/*.mdx    # per-endpoint human docs
   cat /sdks/python.mdx                      # or /sdks/typescript.mdx: method names, config, errors
   ```
   The OpenAPI at `/openapi/api-reference/v2.openapi.json` can lag sources 1–3. A key that sources
   1–3 list and this copy lacks is docs lag, not a bug in the user's code.

Pin a version with `docs_search`'s `version` arg if the project targets one.

## 3. What to flag (judge each call against the live schema)

- **Unknown / renamed method (✗):** the method's path isn't in `.paths`. Confirm against the
  *installed* SDK too (`help(client.search)` / the package `.d.ts`).
- **Wrong body key (✗):** key absent from the endpoint's schema, or camelCase where the schema is
  snake_case (`jobLevel`→`job_level`, `maxResults`→`max_results`), wrong nesting, or wrong type
  (e.g. `max_results` outside the schema's range). Every `/v2` endpoint rejects an unknown field
  at any depth with a `422` — including a stray `page` outside Employee Finder or a misspelled
  `include` / `exclude`. Also check list caps (≤ 50 entries per filter list; Waterfall `cascade` ≤ 10
  tiers, per-tier `location` lists ≤ 10), ranges with `min` > `max`, and both job-history flags
  (`include_active_jobs` / `include_past_jobs`) set `false`. `max_results` has a per-endpoint range
  in the schema, and the MCP's tool schemas cap it lower than REST and the SDKs — judge a call
  against the surface it actually uses.
- **Ignored key (⚠):** a key the endpoint accepts but silently ignores (for example
  `people.linkedin_url` on `/v2/search/people`; see migration-notes.md).
- **Miscased / typo'd enum (✗):** values are case-sensitive and exact-match — the API rejects a
  miss with a `422` that names the field and suggests the closest value (`"vp"`→`"VP"`), so it
  breaks the run without spending records. Match it against the normalization pages.
- **Typo'd free-text filter (✗):** `country_code` (`"USA"`→`"US"`, `"United Kingdom"`→`"GB"`),
  `city`, `job_title`, `keywords` have no list to check against — a wrong value runs clean and
  silently returns 0. This is the worst silent bug now; flag it on sight.
- **Lossy/sparse enum (⚠):** a real-but-rarely-tagged value silently narrows recall — prefer the
  `job_title` / company `keywords` backbone over stacked enum filters.

## 4. Anti-patterns (judgment, no lookup needed)

- **Raw HTTP (✗):** `requests`/`httpx`/`fetch`/`axios` against `api.blitz-api.ai`. Fix: replace with
  the SDK, which does pagination, client-side rate-limiting, and 429/5xx retries that hand-rolled
  HTTP drops.
- **Hardcoded key (✗):** a literal `sk_…` in source. Fix: move to `BLITZ_API_KEY` via `.env`, add
  `.env` to `.gitignore`, and tell the user to **rotate** the exposed key.
- **`.env` not gitignored (⚠).**
- **Manual / truncated pagination (⚠/✗):** a hand-rolled page loop, or reading only page 1 of a
  large population. Prefer the SDK's auto-paging (`for … in client.search.people(...)`,
  `.auto_paging_iter(max_items=…)` / `for await`, `.collect()`).
- **Unbounded streaming loop (⚠):** `for … in client.search.people(...)` with no `max_items`,
  `break` or `.auto_paging_iter(max_items=…)` walks every match up to the ceiling (up to 50,000
  records, each one billed) — fine when the full pull is intended and sized, a finding when it isn't.
- **Unguarded US-only phone (⚠):** `enrichment.phone` on a non-US contact returns nothing,
  `phone-to-person` takes US numbers only, and phone is not part of the free trial (paid plan only).
- **Removed or renamed names (✗):** a field, header, exception or key that has been replaced
  (`remaining_credits`, `InsufficientCreditsError`, the `x-credit-*` headers, `field_of_study`, …).
  migration-notes.md in this folder lists them with the current name — check the code against it,
  and confirm against `util_changelog` since newer entries won't be there yet.

## Without the MCP

Sources 2 and 4 above work from public URLs (the docs at https://docs.blitz-api.ai, append `.md` to
a page for plain text; the SDK guides at https://docs.blitz-api.ai/sdks/overview). Mark the affected
checks ⚠ (lower confidence): the tool schemas aren't available and the docs can lag the changelog.
If the `blitz-gtm-brainstorm` skill is installed, its `scripts/pull_enums.sh search <enum> "<value>"`
checks an enum value live against the same spec.
