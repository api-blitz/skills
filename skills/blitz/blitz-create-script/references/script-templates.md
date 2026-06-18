# Script templates

Adapt these to the brief: substitute the real filters, enrichment toggles, and output target.
The SDK auto-paginates and rate-limits, so there is **no cursor loop** — iterate the search
directly. Pick **single-population** unless `volume.exceeds_ceiling: true`, then use
**partitioned**.

**Credit discipline:** collect → dedupe on `linkedin_url` → enrich the survivors. The
single-population template enriches inline only because a single population has no duplicates; the
partitioned template must dedupe *before* enriching (shown below). Either way, enrich only rows
you'll keep — see [error-handling.md](error-handling.md).

## Python — single population (Find People → enrich → CSV)

```python
import csv, sys
from blitz_api import BlitzAPI

client = BlitzAPI()  # reads BLITZ_API_KEY from env (.env)

# Preflight: fail fast on a bad key / exhausted plan / missing endpoint.
info = client.account.key_info()
if not getattr(info, "valid", False):
    sys.exit("Invalid API key — set BLITZ_API_KEY in .env")

rows = []
# Filters come straight from the brief. SDK streams ALL pages.
for person in client.search.people(
    company={"industry": {"include": ["Software Development"]},
             "employee_range": ["51-200", "201-500"],
             "hq": {"country_code": ["US"]}},
    people={"job_title": {"include": ["Head of Sales", "VP Sales"]},   # from the brief; keyword — use "[..]" for exact
            "job_level": ["VP", "Director"],
            "job_function": ["Sales & Business Development"],
            "location": {"country_code": ["US"]}},                     # person location, distinct from company.hq
):
    li = person.linkedin_url
    email = client.enrichment.email(person_linkedin_url=li)          # any leads plan
    country = person.location.country_code if person.location else None
    phone = client.enrichment.phone(person_linkedin_url=li) if country == "US" else None  # US only
    rows.append({
        "first_name": person.first_name,
        "last_name": person.last_name,
        "headline": person.headline,
        "linkedin_url": li,
        "email": email.email if email.found else "",
        "phone": phone.phone if (phone and phone.found) else "",
        "country": country or "",
    })

cols = ["first_name", "last_name", "headline", "linkedin_url", "email", "phone", "country"]
with open("leads.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=cols)
    w.writeheader(); w.writerows(rows)
print(f"Wrote {len(rows)} leads to leads.csv")
```

## Python — partitioned (population over the ceiling)

```python
# Split the one too-big query into MECE segments (brief.volume.partition_plan), collect every
# page per segment, union, and dedupe by linkedin_url so nothing is silently truncated.
seen = {}
SEGMENTS = ["51-200", "201-500", "501-1000", "1001-5000"]   # from the brief
for seg in SEGMENTS:
    for person in client.search.people(
        company={"industry": {"include": ["Software Development"]},
                 "employee_range": [seg],
                 "hq": {"country_code": ["US"]}},
        people={"job_level": ["VP", "Director"]},
    ):
        seen[person.linkedin_url] = person      # dedupe key = linkedin_url
people = list(seen.values())   # deduped survivors
print(f"Collected {len(people)} unique people across {len(SEGMENTS)} segments")
# Enrich the deduped list in a SEPARATE pass (never inside the segment loop above — that
# re-enriches duplicates and burns credits), then write CSV as in the single-population template:
#   for person in people:
#       email = client.enrichment.email(person_linkedin_url=person.linkedin_url)
#       ...
```

## TypeScript / JavaScript — single population

The block below is **TypeScript** — save as `script.ts` and run under a TS runtime: `bun run
script.ts`, or `npx tsx script.ts` without bun (bare `node script.ts` won't strip the types).

For a **`javascript`** brief, respect that choice: save the same code as `script.mjs`, drop the
three type annotations (`: Record<string, string>[]`, `(v: unknown)`, `new Map<string, any>()` →
`[]`, `(v)`, `new Map()`), keep the ESM `import`s, and run `node script.mjs` (the `.mjs` extension
is ESM with no `package.json` `"type"` needed) or `bun run script.mjs`.

```ts
import { BlitzAPI } from "blitz-api-js";
import { writeFileSync } from "node:fs";

const client = new BlitzAPI(); // reads BLITZ_API_KEY

const info = await client.account.key_info();
if (!info.valid) { console.error("Invalid API key — set BLITZ_API_KEY"); process.exit(1); }

const cols = ["first_name", "last_name", "headline", "linkedin_url", "email", "phone", "country"];
const rows: Record<string, string>[] = [];

for await (const person of client.search.people({
  company: { industry: { include: ["Software Development"] },
             employee_range: ["51-200", "201-500"],
             hq: { country_code: ["US"] } },
  people: { job_title: { include: ["Head of Sales", "VP Sales"] },   // from the brief; keyword — use "[..]" for exact
            job_level: ["VP", "Director"],
            job_function: ["Sales & Business Development"],
            location: { country_code: ["US"] } },                    // person location, distinct from company.hq
})) {
  const li = person.linkedin_url;
  const email = await client.enrichment.email({ person_linkedin_url: li });
  const country = person.location?.country_code ?? null;
  const phone = country === "US" ? await client.enrichment.phone({ person_linkedin_url: li }) : null;
  rows.push({
    first_name: person.first_name ?? "", last_name: person.last_name ?? "",
    headline: person.headline ?? "", linkedin_url: li,
    email: email.found ? email.email : "", phone: phone?.found ? phone.phone : "",
    country: country ?? "",
  });
}

// RFC-4180 CSV escaping: double embedded quotes, quote any field with a comma/quote/newline.
const esc = (v: unknown) => {
  const s = String(v ?? "");
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
const csv = [cols.join(","), ...rows.map(r => cols.map(c => esc(r[c])).join(","))].join("\n");
writeFileSync("leads.csv", csv);
console.log(`Wrote ${rows.length} leads to leads.csv`);
```

## TypeScript — partitioned

```ts
const seen = new Map<string, any>();
const SEGMENTS = ["51-200", "201-500", "501-1000", "1001-5000"]; // from the brief
for (const seg of SEGMENTS) {
  for await (const person of client.search.people({
    company: { industry: { include: ["Software Development"] },
               employee_range: [seg], hq: { country_code: ["US"] } },
    people: { job_level: ["VP", "Director"] },
  })) {
    seen.set(person.linkedin_url, person); // dedupe key = linkedin_url
  }
}
const people = [...seen.values()];   // deduped survivors
console.log(`Collected ${people.length} unique people across ${SEGMENTS.length} segments`);
// Enrich the deduped list in a SEPARATE pass (never inside the segment loop above — that
// re-enriches duplicates and burns credits), then write CSV as in the single-population template.
```

## Adapting per endpoint
- **Company Search** → `client.search.companies({ company: {...} })`; rows are companies; usually
  no per-person enrichment (optionally `enrichment.company`).
- **Employee Finder** → `client.search.employee_finder({ company_linkedin_url, ... })`; one company,
  page-paginated; SDK still streams via `for ...`/`for await`.
- **Waterfall ICP** → `client.search.waterfall_icp({ company_linkedin_url, cascade, max_results })`;
  iterate a list of accounts, one call each; each result item exposes `.person`, `.icp`, `.ranking`.
- **JSON output** → collect `rows`/`people` and `json.dump` / `JSON.stringify` instead of CSV.
- Enriching every record makes one paid API call per record; the SDK throttles to `rate_limit_rps`
  per client. Rate limits are per endpoint, so when you enrich both `/email` and `/phone`, a separate
  client per endpoint lets each run at its own RPS concurrently instead of sharing one budget. Dedupe
  on `linkedin_url` and apply any ICP cleanup *before* enriching, and on very large runs enrich only
  what you'll actually contact (cap with `max_items` / `auto_paging_iter`).
