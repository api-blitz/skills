# The review checklist (run in order, report once)

Run every check, then present **one** report: collect findings, show the checklist, then work the
remediation queue with the user. Severity legend:

- **✓ pass** — healthy, nothing to do.
- **⚠ warn** — works today but suboptimal or risky (stale version, throttled below allowed RPS,
  lossy enum, missing US-phone guard, `.env` not gitignored).
- **✗ fail** — broken, rejected by the API, or will silently return nothing (MCP missing, SDK
  absent, unknown method, wrong body key, miscased enum, typo'd free-text filter, invalid/expired
  key).

## The checks

| # | Check | Pass when | Warn when | Fail when | How |
|---|-------|-----------|-----------|-----------|-----|
| 1 | **Blitz MCP** | Blitz MCP connected | user declined the recommendation (note degraded confidence) | not installed and not yet recommended | own tools / `check_mcp.sh` → `mcp-setup.md` |
| 2 | **Skills version** | local == latest | local behind latest | can't read local plugin.json | `check_skills.sh` |
| 3 | **SDK version** | installed == latest | installed behind latest | not installed | `check_sdk.sh <python\|javascript>` |
| 4 | **SDK methods** | call maps to a real `.paths` entry | — | unknown/renamed method, a removed or renamed name (see migration-notes.md), or raw HTTP to `api.blitz-api.ai` | scan → live schema → `code-audit.md` |
| 5 | **Request bodies** | keys match the live schema | a key the endpoint ignores (see migration-notes.md) | unknown/wrong/camelCase key (a `422`), wrong type, list over its cap, `max_results` out of range | tool schema / public OpenAPI → `code-audit.md` |
| 6 | **Enum values** | all values exist, exact case | lossy/sparse enum filtering recall | miscased/typo'd enum (a `422`), or a typo'd free-text filter such as `country_code: "USA"` (a silent zero) | normalization pages / public OpenAPI → `code-audit.md` |
| 7 | **API key + RPS** | valid, per-endpoint RPS not under-used | code `rate_limit_rps` below the key's allowed RPS, workers over-subscribing one endpoint, low records, or a higher tier would help | invalid/expired key, missing required `allowed_apis`, phone on a trial key | `check_key.sh` → `key-and-rps.md` |
| 8 | **Key safety** | key from env, `.env` gitignored | `.env` present but not gitignored | hardcoded key in source | scan → `code-audit.md` |
| 9 | **Pagination** | uses SDK auto-paging / `auto_paging_iter` | manual page loop that should auto-page | reads only page 1 of a large population | scan → `code-audit.md` |

## Report format

Print a compact checklist, then the detail for every non-pass line, then the remediation queue.

```
Blitz Reviewer — <project name>
MCP: <installed | MISSING> · SDK: blitz-api-py <x> (latest <y>) · Skills: <local> (latest <z>)

  ✓ 1 MCP installed
  ✗ 3 SDK outdated — blitz-api-py 1.2.0 < 1.4.1
  ✗ 5 wrong body key — src/leads.py:42 uses `jobLevel` (snake_case: `job_level`)
  ✗ 6 miscased enum — src/leads.py:43 "vp" is not a JobLevel value (use "VP")
  ⚠ 7 RPS throttled — src/leads.py:12 leaves rate_limit_rps at the default 5; the key allows 10 per endpoint
  ⚠ 8 .env not gitignored

Summary: 1 pass · 2 warn · 3 fail
```

Each non-pass line carries: **where** (file:line or "environment"), **what's wrong**, and the
**fix**. Order the remediation queue fail → warn, environment fixes before code edits (a fresh SDK
can change which methods exist).

## Remediation queue (confirmation-gated)

Propose fixes one at a time; apply only on an explicit yes. Default remediations:

- **MCP missing** → walk the install steps in `mcp-setup.md`; offer to add it.
- **Skills behind** → `npx skills@latest add api-blitz/skills` (or refresh the plugin).
- **SDK behind/absent** → the exact upgrade/install line from `check_sdk.sh`
  (`uv add blitz-api-py@latest` / `bun add blitz-api-js@latest`, or pip/npm equivalents).
- **Wrong method / raw HTTP** → rewrite the call against the SDK, validating the endpoint and body
  against the live schema (SDK guides: https://docs.blitz-api.ai/sdks/overview).
- **Wrong body key / enum** → correct in place against the live schema (tool schema or the public
  OpenAPI, https://api.blitz-api.ai/openapi; with `blitz-gtm-brainstorm` installed, its
  `scripts/pull_enums.sh search <enum> "<value>"` checks enum values live).
- **RPS under-used (throttled below the key's allowed RPS) / records / tier** → see
  `key-and-rps.md`; ask before any change.
- **Hardcoded key** → move to `BLITZ_API_KEY` in `.env`, add `.env` to `.gitignore`, and tell the
  user to rotate the exposed key.

If a check couldn't run (offline, no key, MCP declined), say so explicitly — never report a skipped
check as a pass.
