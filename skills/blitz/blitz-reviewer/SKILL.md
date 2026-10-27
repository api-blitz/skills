---
name: blitz-reviewer
description: Audit a Blitz integration against the live Blitz MCP before it runs, covering MCP, SDK and skill versions, call bodies and enums, and key limits. Use when the user asks to review, audit or preflight Blitz code or setup, especially before a run at scale.
---

# Blitz Reviewer

Audit a Blitz integration across the **environment** (MCP, SDK, skills, API key) and the **user's
own code** (methods, bodies, enums). Output: one pass/warn/fail checklist, then a remediation queue
where each fix waits for the user's yes.

**Source of truth: the live schema.** Judge every call against what Blitz serves now — the MCP
tool's own input schema (already in your tool list), the public OpenAPI
(`curl -s https://api.blitz-api.ai/openapi`, no key) and `util_changelog`, the newest word. The copy
of the OpenAPI that `docs_read` serves under `/openapi/` can lag these, so read a disagreement with
them as docs lag. The MCP is checked first because it supplies the tool schemas and the changelog.

Run the read-only checks, collect findings into one report, then work the remediation queue one
confirmed fix at a time.

## Quick start

Work the checks in order, collect every finding, then present one checklist and a
confirmation-gated remediation queue. The report looks like this (full format in
[references/checklist.md](references/checklist.md)):

```
Blitz Reviewer — my-project
  ✓ 1 MCP installed
  ✗ 5 wrong body key — src/leads.py:42 uses `jobLevel` (use `job_level`)
  ⚠ 7 RPS throttled — rate_limit_rps left at the default 5; the key allows 10 per endpoint
Summary: 1 pass · 1 warn · 1 fail
```

`scripts/` and `references/` paths are relative to this skill's own directory — run helpers from
there (e.g. `bash <skill-dir>/scripts/check_mcp.sh`). Without the MCP, the public OpenAPI and docs
(https://api.blitz-api.ai/openapi, https://docs.blitz-api.ai) still cover bodies and enums at lower
confidence, and the report says so.

## Workflow

1. **MCP (check first).** See whether your own tools include the Blitz MCP (`docs_search`,
   `docs_read`, and the `people_*` / `company_*` / `job_*` API tools); if unclear, run
   `bash scripts/check_mcp.sh`. When it's missing, recommend installing it before you continue,
   because it supplies the live tool schemas and changelog for checks 4–6. Give the steps for
   *their* agent (Claude Code, Cursor, VS Code, Windsurf, Codex, claude.ai, …), link
   https://docs.blitz-api.ai/guide/integrations/MCP, and offer to add it. If the user declines,
   continue on the public sources and **flag the degraded confidence**. See
   [references/mcp-setup.md](references/mcp-setup.md).

   Done when check 1 has a verdict: connected (✓), declined (⚠) or missing (✗).

2. **Skills up to date.** `bash scripts/check_skills.sh` compares the installed plugin version
   against the latest on [`api-blitz/skills`](https://github.com/api-blitz/skills). Queue the update
   if behind; offline → warn and move on.

   Done when check 2 has a verdict.

3. **SDK up to date.** `bash scripts/check_sdk.sh <python|javascript>` reports installed vs latest
   (PyPI `blitz-api-py` / npm `blitz-api-js`). Queue an upgrade or install if outdated or missing;
   the SDK stays the client.

   Done when check 3 has a verdict.

4. **Scan the code, then validate each call against the live schema.** Grep the project for Blitz
   call sites (patterns in [references/code-audit.md](references/code-audit.md)). Compare each one
   with the live endpoint, request-body schema and enum values, and flag unknown or renamed
   methods, wrong or camelCase body keys, miscased enums, typo'd free-text filters such as
   `country_code: "USA"` (these run clean and return nothing), and anti-patterns. Removed and
   renamed names to recognise in old code:
   [references/migration-notes.md](references/migration-notes.md).

   Done when every call site the grep found has a verdict and a `file:line`.

5. **API key, RPS & records.** Read key health via the SDK (`client.account.key_info()`) or
   `BLITZ_API_KEY=… bash scripts/check_key.sh`. Report `valid`, `records_remaining`,
   `next_reset_at`, `max_requests_per_seconds` and `allowed_apis`, and compare the code's
   `rate_limit_rps` with the key's allowed RPS (rules in
   [references/key-and-rps.md](references/key-and-rps.md)). Ask before requesting any tier change.

   Done when those five fields are reported and `rate_limit_rps` is compared.

6. **Report & remediate.** Present the pass/warn/fail checklist (format in
   [references/checklist.md](references/checklist.md)), then work the remediation queue top to
   bottom, applying each fix after the user confirms it.

   Done when every queued fix is applied, declined or deferred.

## Rules

- Spend no records. `key_info` is free, as are the `docs_*` tools and the tool schemas; the API
  tools (`people_*`, `company_*`, `job_*`) and any search or enrichment bill records, so a review
  leaves them uncalled.
- Every change waits for explicit confirmation: installing the MCP, upgrading the SDK or skills,
  editing code, changing the key or RPS.
- Mask the API key (`sk_…last4`) wherever it appears, and keep it out of files.
