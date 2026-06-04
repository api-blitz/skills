# How to think about a Blitz search (strategy)

This is the *judgment* layer behind the mechanics — the way of thinking that turns a goal into a
search that actually returns the right people at the right volume. It is **direction, not dogma**:
heuristics to reason with, not rules to obey. Endpoint shapes and enum lists live in the other
references; this is *how to wield them*. Adapt freely — imagination is the limit.

## The first decision is the ICP, not the endpoint

Everything downstream inherits the ICP, so get *who you're targeting* and *how tight* right before
anything else — the endpoint and filters are just how you express it. When the ICP boundary is
fuzzy, **ask the user** rather than guessing; an over-tight or over-loose ICP wastes the whole run.

## Recall first: most fields are sparse, and silence is the failure mode

There are **two** ways a search underperforms, and only the first is obvious:

1. **Enum typo → hard 0 results.** Case-sensitive values silently return nothing on any mismatch
   (`"vp"` ≠ `"VP"`). Covered in [enums-snapshot.md](enums-snapshot.md).
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
sparse enums only when you *need* the precision and can afford the recall hit — each one you add can
silently shrink the pool to tagged-only records. **De-noise by reviewing a sample and iterating the
keywords, not by stacking lossy enum filters.**

## `job_title` is full-text search — spray it

`job_title.include` is FTS (no brackets) and multiple values OR together, so more variants = more
matches. Within the *true* ICP, cast wide:

- **Synonym / semantic clusters:** `Head of Sales`, `VP Sales`, `Sales Director`, `CRO`, `Revenue`…
- **Multilingual** when the geo spans languages: `HR` / `RH` / `DRH` / `Human Resources` /
  `Ressources Humaines`.
- **Long *and* short forms:** `VP` *and* `Vice President`; `HR` *and* `Human Resources`.
- No-bracket keyword match catches variants like `Co-CEO`, `CEO Office`; `[CEO]` is exact-only.
  Flip `include_linkedin_headline: true` to also match the headline — broader, noisier.

## Probe cheaply, tune to saturation, then pull

Population size is free to read and expensive to pull — so **never pull just to learn how big it is.**

1. Fire each candidate query/segment at **`max_results: 1`** and read **`total_results`** (Find
   People / Company Search) or **`total_pages`** (Employee Finder). `scripts/probe_volume.sh` forces
   `max_results: 1` for exactly this.
2. Add title/keyword variants and adjust geo/headcount, re-probing, until the number stops climbing.
3. **Stop when** any of these is true: `total_results` saturates as you add variants; you've
   enumerated the known title/geo space; new variants only add off-ICP noise; you've hit the user's
   target count.
4. *Then* do the full pull.

**Fidelity gate:** maximize recall *within the real ICP* — never bolt on off-target keywords just to
inflate the number. Volume that isn't in the ICP is worse than no volume.

## The ~50k ceiling is per-query — partition to get *past* it

Find People / Company Search top out around **50k reachable results per query** (Employee Finder
~10k per company), and Blitz **silently truncates** beyond that. The move isn't to give up — it's to
**split the ICP into MECE segments that each sit under the ceiling, run them all, union, and dedupe
on `linkedin_url`.** Most people under-deliver here by under-splitting and capping themselves at one
query's worth. Partition on **dense** axes so the split itself doesn't leak:

- **Geography** — `country_code`, then region, then **city** (keyword-matched, very granular).
- **`employee_range` / `employee_count`** buckets (already MECE).
- **Keyword / title clusters** — run the HR cluster, the Finance cluster, etc. as separate segments.

**Don't partition on a sparse enum** (`industry`, `job_level`): each segment would leak the untagged
majority. Full mechanics in [volume-and-partition.md](volume-and-partition.md).

## Enrich last, and only what survives

Enrichment costs credits per call, so spend them only on keepers:

> **search → dedupe on `linkedin_url` → post-hoc ICP cleanup → enrich the survivors.**

Never enrich duplicates or rows you're about to discard. Email is broadly available; **phone is
US-only** — gate on `country_code == "US"`, and only when the user actually asked for phones.

## Endpoint mindset: volume vs. precision (the model flips)

- **Find People / Company Search — volume, keyword-first.** Everything above applies. Find People
  returns people across many companies in one call; Company Search returns the companies themselves
  (same company-filter object) — use it to build an **account list** that feeds the named-account
  motions. You don't *need* to chain for people-by-ICP; Find People does that directly.
- **Waterfall ICP — precision, one named account.** A **priority ranking**, not a seniority ladder:
  tier 1 is the *perfect* contact; lower tiers are looser matches *or a different persona* you'd
  accept. `max_results: 5` fills top-down through the cascade (5 C-levels if it can, else backfills
  with Directors). Each hit returns an **`icp`** (which tier matched) and **`ranking`** (relevance
  in the company) — `icp` is a ready-made **persona signal you can use to tailor outreach copy**
  (a possibility, not a requirement). Spray FTS title variants *within* each tier; turn
  `include_headline_search` on only in the noisy fallback tiers. Person data nests under
  `results[].person`.
- **Employee Finder — a whole department, or a head-count.** Filters are enum-only
  (`job_level` / `job_function` / `sales_region`) — **no `job_title` keyword**, so the keyword-recall
  trick isn't available here. Best for *exporting a full team* or *sizing a company* (read
  `total_pages`), not for hunting one buyer — for that, switch to Waterfall. Person fields come back
  flat in `results[]` (not nested).

For a list of named accounts: resolve any bare domains to `company_linkedin_url` via
**domain-to-linkedin** first, then loop one call per account.
