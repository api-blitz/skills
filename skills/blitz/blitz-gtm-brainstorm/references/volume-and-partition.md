# Volume probing and partition-for-scale

Blitz silently truncates past a pagination ceiling: match more than the reachable maximum and
the surplus is dropped with **no error**. But the ceiling is **per query**, so partitioning isn't
only damage control — it's how you deliberately pull *past* it: split the ICP into segments that
each sit under the ceiling, run them all, union, and dedupe. Most people under-deliver by
under-splitting and capping themselves at one query's worth. Size the population first (cheaply),
then partition to capture the rest. The recall-first thinking behind this: [strategy.md](strategy.md).

## Reachable ceilings

| Endpoint | Page size | Page cap | Reachable max | Probe field |
|----------|-----------|----------|---------------|-------------|
| Find People | 50 | ~1,000 | **~50,000** | `total_results` |
| Company Search | 50 | ~1,000 | **~50,000** | `total_results` |
| Employee Finder | 50 | ~200 | **~10,000 / company** | `total_pages` |
| Waterfall ICP | n/a | n/a | 1 best match (×`max_results`) | n/a — never partition |

## Probe

Run a 1-result call and read the count (the helper forces `max_results: 1`):
```bash
echo '{"company":{"keywords":{"include":["devtools"]},"hq":{"country_code":["US"]}},
       "people":{"job_title":{"include":["VP Engineering","Head of Engineering"]}}}' \
  | BLITZ_API_KEY=sk_... bash scripts/probe_volume.sh /v2/search/people
# → { "total_results": 18342, "total_pages": null, "cursor": "…", "results_length": 1 }
```
- Find People / Company Search → use `total_results`.
- Employee Finder → use `total_pages` (× page size ≈ population).

Re-probe as you tune: add `job_title`/keyword variants and adjust geo/headcount until `total_results`
**saturates** (stops climbing). Saturation — or the user's target count — is your stop signal, and
it costs nothing because every probe is `max_results: 1`. See [strategy.md](strategy.md).

Set in the brief:
```yaml
volume:
  estimate: 18342
  probe_method: total_results   # total_results | total_pages | manual
  exceeds_ceiling: false        # true when estimate > reachable max above
  partition_plan: []            # filled only when exceeds_ceiling
```

## Partition strategy (when `exceeds_ceiling: true`)

Split the one too-big query into MECE (mutually exclusive, collectively exhaustive) segments,
paginate each fully, then union and **dedupe by `linkedin_url`**. Split on **dense** axes, so the
partition itself doesn't drop the untagged majority:

1. **`employee_range` / `employee_count`** first — already bucketed and MECE
   (`1-10`, `11-50`, `51-200`, `201-500`, `501-1000`, `1001-5000`, `5001-10000`, `10001+`).
2. If a bucket still exceeds the ceiling, split by **geography** — `hq.country_code`, then
   `sales_region`, then **city** (keyword-matched, very granular).
3. If still too big, split the **`job_title` keyword set into clusters** (e.g. an HR cluster, a
   Finance cluster) and run each as its own segment.

**Do not partition on a sparse enum** (`industry`, `job_level`, `job_function`): each segment would
silently leak everyone not tagged with that value, defeating the purpose. Use the dense axes above.

Each segment must stay under the reachable max (re-probe segments you are unsure about).

```yaml
partition_plan:
  - dimension: employee_range
    segments: ["51-200", "201-500", "501-1000", "1001-5000"]
  - dimension: hq.country_code      # only for segments still over the ceiling
    segments: ["US", "GB", "CA"]
```

`blitz-create-script` turns this into a loop that runs the search once per segment, collects all
pages, and dedupes by `linkedin_url` before enrichment — so no lead is silently dropped.
