---
name: blitz-create-script
description: Generates a runnable lead-generation or enrichment script against the official Blitz SDK (blitz-api-py or blitz-api-js), installs it with the best available package manager (uv or pip for Python, bun or npm for JS/TS), and adds API-key safety, baseline error handling, and correct pagination including partition-for-scale. Use when the user wants to turn a GTM brief into working code, scaffold a Blitz People/Company/Employee search or email/phone enrichment job, or says "write the script", "build the integration", or "generate code for this ICP". Consumes a gtm-brief.yaml from blitz-gtm-brainstorm or works standalone.
---

# Blitz Create Script

Turn a GTM brief into a runnable Blitz script that uses the **official Blitz SDK**
(`blitz-api-py` / `blitz-api-js`), installs it with the best package manager, and ships with
API-key safety, baseline error handling, and correct pagination.

The SDK handles pagination, client-side rate-limiting, and 429/5xx retries for you. **Never emit
raw `fetch`/`requests`** — that re-introduces every bug the SDK exists to remove.

## Quick start

Load `./gtm-brief.yaml` (or have the user paste it, or run `blitz-gtm-brainstorm` first). Then
work the steps below and output one runnable script plus `.env`.

`scripts/` and `references/` paths below are relative to this skill's own directory — run the
helpers from there (e.g. `bash <skill-dir>/scripts/detect_pm.sh`), not the user's project root.

## Workflow

1. **Load the brief.** Read `./gtm-brief.yaml` if present; else ask the user to paste it; else
   reconstruct the minimum by a short interview (endpoint, filters, enrichment, output, language).
   Schema: `../blitz-gtm-brainstorm/references/gtm-brief-schema.md`.

2. **Check enum validation (for any enums the brief uses).** If the brief uses categorical enums
   and `enums_verified` is not `true`, stop and send the user to `blitz-gtm-brainstorm` (or validate
   now via its `scripts/pull_enums.sh`) — a typo'd case-sensitive enum runs clean and returns
   nothing. A keyword-only brief needs no gate. (A *low but non-zero* count instead usually means a
   lossy enum is filtering to tagged-only records — prefer the keyword backbone:
   `../blitz-gtm-brainstorm/references/strategy.md`.)

3. **Detect the package manager.** `bash scripts/detect_pm.sh <python|typescript>` →
   Python: `uv` → `poetry` → `pip` (+venv). JS: `bun` → `pnpm` → `yarn` → `npm`.

4. **Install and verify the SDK.** Install (`uv add blitz-api-py` / `bun add blitz-api-js` / pip /
   npm), then `bash scripts/verify_sdk.sh <python|typescript>`. If install or import fails, show
   the exact error and the install command and **stop** — do NOT fall back to raw HTTP. A failed
   install is the signal to fix the environment, not to hand-roll the client.

5. **Generate the script** from [references/script-templates.md](references/script-templates.md):
   - `volume.exceeds_ceiling: false` → **single-population** template (SDK auto-paginates).
   - `volume.exceeds_ceiling: true` → **partitioned** template: loop the `partition_plan`
     segments, collect all pages per segment, union, and **dedupe by `output.dedupe_key`**.
   Map the brief's filters straight into the SDK call. Method surface and client config:
   [references/sdk-reference.md](references/sdk-reference.md).

6. **Safety and errors.** Read the key from `BLITZ_API_KEY` (`.env`; add `.env` to `.gitignore`).
   Add a `/v2/account/key-info` preflight, and handle `found == false`, empty results, and the
   US-only phone caveat. See [references/error-handling.md](references/error-handling.md).

7. **Tell the user how to run it** (`uv run script.py` / `bun run script.ts`), and which env vars
   to set (`BLITZ_API_KEY`).

## Rules

- Enforce the SDK. Never generate raw `fetch`/`requests`. If the SDK cannot install, stop with a
  clear, actionable error.
- Never hardcode the API key; never commit `.env`.
- Phone enrichment is US-only — guard non-US contacts before calling it.
- Honor the brief: if `exceeds_ceiling` is true, the partitioned template is mandatory.
