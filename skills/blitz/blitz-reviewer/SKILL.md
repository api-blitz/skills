---
name: blitz-reviewer
description: Reviews a Blitz API integration against the live Blitz docs before you run it. Confirms the Blitz MCP is installed (and pushes to add it), checks the blitz-api SDK and the Blitz skills are on the latest version, scans your project for wrong SDK methods, malformed request bodies, and case-sensitive enum typos by validating each call against the MCP's OpenAPI specs and normalization pages, and reads your API key's per-endpoint rate limits and credits to flag throughput left on the table. Reports a pass/warn/fail checklist and applies each fix only after you confirm. Use when the user says "review my Blitz integration", "audit my Blitz code", "check my Blitz setup", "is my Blitz usage correct", "preflight my Blitz job", or before running a Blitz job at scale.
---

# Blitz Reviewer

Audit a Blitz integration and report what's healthy, what's stale, and what's wrong — across the
**environment** (MCP, SDK, skills, API key) and the **user's own code** (methods, bodies, enums).

**The Blitz MCP is the source of truth.** Never judge a call against a memorized or bundled API
spec — ask the MCP for the live endpoint, request body, and enum values and compare. That's why the
MCP is checked first and pushed hard: it makes every other check accurate. Output is a
pass/warn/fail checklist; nothing changes until the user confirms each fix.

This is diagnosis, not a refactor. Run the read-only checks, collect findings into one report, then
work a remediation queue one confirmed fix at a time. Spend no credits doing it — `key-info` is
free; never fire a search or enrichment to "test."

## Quick start

Work the checks in order (MCP first — it's what makes checks 4–6 authoritative). Collect every
finding, then present one checklist and a confirmation-gated remediation queue.

`scripts/` and `references/` paths are relative to this skill's own directory — run helpers from
there (e.g. `bash <skill-dir>/scripts/check_mcp.sh`). The sibling-skill references
(`../blitz-create-script/...`, `../blitz-gtm-brainstorm/...`) are a **snapshot fallback** for when
the MCP is unavailable — prefer the live MCP every time.

## Workflow

1. **MCP — required (check first).** Decide whether the Blitz MCP is connected: check whether you
   (whichever agent you are) expose Blitz MCP tools (`search…blitz…`, `query_docs…blitz…`); if
   unclear, run `bash scripts/check_mcp.sh`. **If it's missing, stop and push the user to install
   it** — give the steps for *their* agent (Claude Code, Cursor, VS Code, Windsurf, Codex, claude.ai,
   …), link https://docs.blitz-api.ai/guide/integrations/MCP, and offer to add it. It's what lets
   checks 4–6 validate against the live schema. Only if the user declines, fall back to the snapshot
   references and **flag the degraded confidence**. See [references/mcp-setup.md](references/mcp-setup.md).

2. **Skills up to date.** `bash scripts/check_skills.sh` compares the installed plugin version
   against the latest on [`api-blitz/skills`](https://github.com/api-blitz/skills). Queue the update
   if behind; offline → warn and move on.

3. **SDK up to date.** `bash scripts/check_sdk.sh <python|javascript>` reports installed vs latest
   (PyPI `blitz-api-py` / npm `blitz-api-js`). Queue an upgrade/install if outdated or missing —
   never fall back to raw HTTP.

4. **Scan the code, then validate each call against the MCP.** Grep the project for Blitz call
   sites (imports, `client.search.*` / `.enrichment.*` / `.account.*`, and raw-HTTP to
   `api.blitz-api.ai`). For each one, **ask the MCP** for the authoritative endpoint, request-body
   schema, and enum values, and compare — flag unknown/renamed methods, wrong or camelCase body
   keys, miscased enums (case-sensitive — a typo runs clean and returns nothing), and anti-patterns.
   Query recipes and the grep patterns: [references/code-audit.md](references/code-audit.md).

5. **API key, RPS & credits.** Read key health via the SDK (`client.account.key_info()`) or
   `BLITZ_API_KEY=… bash scripts/check_key.sh`. Report `valid`, `remaining_credits`,
   `max_requests_per_seconds`, and `allowed_apis`. Limits are **per endpoint**, not a shared account
   pool: flag both a `rate_limit_rps` set **below** an endpoint's allowed RPS *and* a single shared
   client throttling several endpoints that are called *concurrently* (give each its own client; a
   sequential loop gains nothing from the split). Ask before requesting any tier change. See
   [references/key-and-rps.md](references/key-and-rps.md).

6. **Report & remediate.** Present the pass/warn/fail checklist (format in
   [references/checklist.md](references/checklist.md)), then work the remediation queue top to
   bottom — apply each fix only after the user confirms it.

## Rules

- MCP first, and push for it. The MCP is the source of truth; only fall back to the snapshot
  references if the user declines, and say so (lower confidence) in the report.
- Diagnose, don't spend. `key_info` only — never run a search or enrichment to test during a review.
- Never modify anything without explicit confirmation — installing the MCP, upgrading the SDK or
  skills, editing code, or changing the key/RPS all wait for a yes.
- Never print the full API key or write it anywhere; mask it (`sk_…last4`).
- Enforce the SDK. Flag raw `fetch`/`requests` against `api.blitz-api.ai` as a finding, not a nit.
