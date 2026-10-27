# Migration notes — removed and renamed names (dated snapshot)

The one place in these skills that carries dates and version numbers on purpose. It is a snapshot
as of 2026-10-27; the live changelog (the MCP's `util_changelog`, or `GET /changelog`, no key
needed) supersedes it. Use it to recognise **old code** during checks 4–6 — it is not a description
of how to write new code.

| Old (flag it) | Now | Since |
|---------------|-----|-------|
| `remaining_credits` on key-info | `records_remaining` | 2026-09-01 |
| `x-credit-cost` / `x-credit-remaining` response headers | `x-records-used` / `x-records-remaining` | 2026-08-31 |
| `InsufficientCreditsError` | `InsufficientRecordsError` (Python) / `FairUsageLimitError` (JS). The docs call the old name a deprecated alias, but blitz-api-py 4.x and blitz-api-js 3.x do not export it, so an `except` / `instanceof` on it breaks | SDK majors |
| `education[].field_of_study` | folded into `degree` | 2026-09-15 |
| `profile_picture_url` | still present, always `null` | 2026-09-15 |
| `headline` = the LinkedIn free text | now `<job title> \| @<employer>` from the first position | 2026-09-15 |
| `people.linkedin_url` on `/v2/search/people` | silently ignored (still valid on `/v2/company/tam-by-people`) | 2026-09-11 |
| unknown request field, at any depth | `422` naming the field (it used to be dropped) | 2026-09-28 |
| a filter list over 50 entries | `422`; a waterfall `cascade` is capped at 10 tiers | 2026-09-15 |
| waterfall `cascade[].location` as a list of up to 50 codes | still accepted, but capped at 10 values; an object (`city` / `country_code` / `continent` / `sales_region`) is also accepted | 2026-10-20 |
| MCP `max_results` above 25 on `people_search` / `people_employee_finder`, above 50 on `people_waterfall_icp` | rejected by the MCP (REST and SDK limits are unchanged) | 2026-10-16 |
| a range with `min` above `max` | `422` (it used to return nothing, or a `500` on revenue) | 2026-09-16 |

Docs and the OpenAPI sometimes lag the changelog. On 2026-10-27 the OpenAPI that `docs_read` serves
under `/openapi/` still showed the waterfall `location` as a list only and lacked
`people.job_description` and `company.mx` on the job endpoints, while the changelog, the public
`https://api.blitz-api.ai/openapi` and the MCP tool schemas had them; the SDK types lag too. When
sources disagree, the changelog is the newer word — and say so in the report rather than flagging
working code.
