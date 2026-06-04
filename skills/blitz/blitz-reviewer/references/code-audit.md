# Auditing the user's Blitz code — find the calls, then ask the MCP

Checks 4–5 of the [checklist](checklist.md). The flow is: **find every Blitz call site** (grep —
deterministic), then **validate each against the live Blitz MCP** (the source of truth for
endpoints, request bodies, and enum values). Don't validate against memory or a bundled spec — the
real surface changes (new enrichment endpoints, renamed fields, added enum values), and a stale
assumption is exactly the bug this skill exists to catch.

## 1. Find the call sites (grep)

Scan the project (skip `node_modules`, `.venv`, `dist`, `.git`). Useful patterns:

```
BlitzAPI|AsyncBlitzAPI|blitz_api|blitz-api-js          # imports / client construction
\.search\.|\.enrichment\.|\.account\.                  # SDK method calls
api\.blitz-api\.ai|requests\.|httpx\.|fetch\(|axios    # raw-HTTP anti-pattern
BLITZ_API_KEY|sk_[A-Za-z0-9]{8}                        # key handling (and hardcoded keys)
rate_limit_rps                                          # for the RPS check (key-and-rps.md)
```

Record `file:line` for every hit — findings need a location. The SDK methods mirror the REST paths
1:1 (`client.search.people` → `POST /v2/search/people`, `client.enrichment.email` →
`POST /v2/enrichment/email`, `client.account.key_info` → `GET /v2/account/key-info`), and option
keys are snake_case, identical to the request body. Resolve the exact path from the MCP — don't
assume it.

## 2. Ask the MCP for the authoritative surface

The MCP exposes two tools: **`search_…`** (semantic — best for "how does X work") and
**`query_docs_filesystem_…`** (a read-only `rg`/`cat`/`jq`/`tree` shell over the docs **and OpenAPI
specs**). The specs live at `/openapi/api-reference/v2.openapi.json`. Recipes:

```bash
# Real endpoints (does this method map to a real path?)
jq -r '.paths | keys[]' /openapi/api-reference/v2.openapi.json

# Authoritative request body for an endpoint (keys, types, required, nesting)
jq '.paths["/v2/search/people"].post.requestBody.content["application/json"].schema' \
  /openapi/api-reference/v2.openapi.json

# Enum / normalization values (case-sensitive)
ls /guide/reference/normalization/        # job-levels, industries, companies, geography, filters, urls
cat /guide/reference/normalization/job-levels.mdx
rg -i "software development" /guide/reference/normalization/industries.mdx

# Per-endpoint human docs
cat /api-reference/people-search/*.mdx
```

Use `search_…` first for conceptual questions, then `query_docs_filesystem_…` for exact schema/enum
checks. Pin a version with the search tool's `version` arg if the project targets one.

## 3. What to flag (judge each call against the MCP answer)

- **Unknown / renamed method (✗):** the method's path isn't in `.paths`. Confirm against the
  *installed* SDK too (`help(client.search)` / the package `.d.ts`).
- **Wrong body key (✗):** key absent from the endpoint's schema, or camelCase where the schema is
  snake_case (`jobLevel`→`job_level`, `maxResults`→`max_results`), wrong nesting, or wrong type
  (e.g. `max_results` outside the schema's range).
- **Miscased / typo'd enum (✗):** values are case-sensitive — a wrong-case value filters to nothing
  and the search returns clean with zero results (the worst silent bug). `"vp"`→`"VP"`.
- **Lossy/sparse enum (⚠):** a real-but-rarely-tagged value silently narrows recall — prefer the
  keyword backbone ([../../blitz-gtm-brainstorm/references/strategy.md](../../blitz-gtm-brainstorm/references/strategy.md)).

## 4. Anti-patterns (no MCP lookup needed — judgment)

- **Raw HTTP (✗):** `requests`/`httpx`/`fetch`/`axios` against `api.blitz-api.ai`. Fix: replace with
  the SDK, which does pagination, client-side rate-limiting, and 429/5xx retries that hand-rolled
  HTTP drops.
- **Hardcoded key (✗):** a literal `sk_…` in source. Fix: move to `BLITZ_API_KEY` via `.env`, add
  `.env` to `.gitignore`, and tell the user to **rotate** the exposed key.
- **`.env` not gitignored (⚠).**
- **Manual / truncated pagination (⚠/✗):** a hand-rolled page loop, or reading only page 1 of a
  large population. Prefer the SDK's auto-paging (`for … in client.search.people(...)`,
  `.auto_paging_iter(max_items=…)` / `for await`, `.collect()`).
- **Unguarded US-only phone enrichment (⚠):** `enrichment.phone` on a non-US contact wastes credits.

## Fallback when the MCP was declined

Validate against the snapshots instead, and mark the affected checks ⚠ (lower confidence — they lag
the live schema): methods/bodies in
[../../blitz-create-script/references/sdk-reference.md](../../blitz-create-script/references/sdk-reference.md)
and [../../blitz-gtm-brainstorm/references/endpoint-decision.md](../../blitz-gtm-brainstorm/references/endpoint-decision.md);
enums in [../../blitz-gtm-brainstorm/references/enums.json](../../blitz-gtm-brainstorm/references/enums.json)
(or search live with `../../blitz-gtm-brainstorm/scripts/pull_enums.sh search <enum> "<value>"`).
