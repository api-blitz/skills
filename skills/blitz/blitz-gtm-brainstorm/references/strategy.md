# How to think about a Blitz search (strategy)

The judgment behind the mechanics: how a goal becomes a search that returns the right people at the
right volume. Endpoint behaviour lives in `endpoint-decision.md`, ceilings and partitioning in
`volume-and-partition.md`.

## The first decision is the ICP, not the endpoint

Everything downstream inherits the ICP, so get *who you're targeting* and *how tight* right before
anything else — the endpoint and filters are just how you express it. When the ICP boundary is
fuzzy, **ask the user** rather than guessing; an over-tight or over-loose ICP wastes the whole run.

## Recall first: most fields are sparse, and silence is the failure mode

There are **two** ways a search underperforms, and only the first is obvious:

1. **A wrong value → a 422, or a hard 0.** Categorical enums are case-sensitive (`"vp"` ≠ `"VP"`)
   and the API rejects an unknown one with a `422` that names the field and suggests the closest
   value — loud, and no records spent. `scripts/pull_enums.sh` finds the exact value before you
   call. **Free-text filters are not checked** — `job_title`, `keywords`, `city`, `country_code`
   (`"USA"` ≠ `"US"`) — so a typo there runs clean and silently returns 0.
2. **Correct-but-sparse field → silent recall collapse.** A perfectly-spelled `industry` or
   `job_level` only matches records *tagged* with it — and not every company has an industry
   linked, nor is every person tagged `VP`. So a "clean" search can quietly return a *fraction* of
   the real population: no error, just a smaller number that looks plausible.

The way out is to know which fields are **dense** (nearly everyone has one) versus **sparse** (only
tagged records have one), and build the backbone of the search from the dense ones.

### Coverage map

| Backbone — dense, high-recall | Precision knobs — sparse, lossy |
|---|---|
| `job_title` (full-text; *everyone* has one) | `job_level` (`VP`/`Director`/… — tagged only) |
| company `keywords` (searches description, specialties, NAICS/SIC desc, Crunchbase/G2) | `industry` (tagged only) |
| `location.city` / `hq.city` (keyword-matched) | `job_function` (tagged only) |
| `min_connections`, `employee_range` / `employee_count` | company `type`, `revenue`, `web_traffic`, `ad_spend`, `naics`/`sic` |

Rule of thumb: **lead with `job_title` keywords + company `keywords`/description.** Reach for the
sparse enums when the precision is worth the recall hit — each one you add can silently shrink the
pool to tagged-only records. **De-noise by reviewing a sample and iterating the keywords.**

## `job_title` is full-text search — spray it

`job_title.include` is FTS (no brackets) and multiple values OR together, so more variants = more
matches. Within the *true* ICP, cast wide:

- **Synonym / semantic clusters:** `Head of Sales`, `VP Sales`, `Sales Director`, `CRO`, `Revenue`…
- **Multilingual** when the geo spans languages: `HR` / `RH` / `DRH` / `Human Resources` /
  `Ressources Humaines`.
- **Long *and* short forms:** `VP` *and* `Vice President`; `HR` *and* `Human Resources`. Matching
  is **whole words, in any order, with no stemming or abbreviation expansion** — `Head Marketing`
  matches `Marketing Head`, but `VP` does not match `Vice President` and `Demand Gen` does not
  match `Demand Generation`. Write each form as its own phrase.
- No-bracket keyword match catches variants like `Co-CEO`, `CEO Office`; `[CEO]` is exact-only.
  Flip `include_linkedin_headline: true` to also match the headline — broader, noisier.
- Each `include` / `exclude` list takes at most 50 phrases (more is a `422`).

**Fidelity gate:** maximize recall *within the real ICP*. Volume that isn't in the ICP is worse than
no volume, so every added keyword must describe someone the user would actually contact.

## Volume vs precision

- **Find People, Company Search and the TAM endpoints are volume motions.** Keyword-first; everything
  above applies. Company Search and the TAM endpoints build an **account list** that feeds the
  named-account motions.
- **Waterfall ICP and Employee Finder are precision motions on one named account.** Waterfall ranks
  a cascade of title tiers, so spray FTS title variants *within* each tier. Employee Finder exports a
  whole team or sizes a company with enum-only filters, so the keyword-recall trick is unavailable
  there.
