---
name: blitz-create-script
description: Generate a runnable Blitz SDK script (Python or JS/TS) from a gtm-brief.yaml, covering search, enrichment, pagination and partitioning. Use when the user asks to write, scaffold or build the Blitz integration or lead-gen script.
---

# Blitz Create Script

Turn a GTM brief into a runnable script on the **official Blitz SDK** (`blitz-api-py` /
`blitz-api-js`). The SDK owns pagination, per-endpoint throttling and 429/5xx retries, so every
Blitz call goes through it.

## Quick start

Load `./gtm-brief.yaml` (or have the user paste it, or run `blitz-gtm-brainstorm` first), work the
steps below, and output one runnable script plus `.env`. The commands you will end up running
(Python with uv shown):

```bash
bash <skill-dir>/scripts/detect_pm.sh python   # manager=uv, add=uv add blitz-api-py, run=uv run script.py
uv add blitz-api-py && bash <skill-dir>/scripts/verify_sdk.sh python
uv run --env-file .env script.py                # BLITZ_API_KEY lives in .env (gitignored)
```

This skill works standalone and pairs with `blitz-gtm-brainstorm` (brief schema, enum validation).

`scripts/` and `references/` paths below are relative to this skill's own directory — run the
helpers from there (e.g. `bash <skill-dir>/scripts/detect_pm.sh`), not the user's project root.

## Workflow

1. **Load the brief.** Read `./gtm-brief.yaml` if present; else ask the user to paste it; else
   reconstruct the minimum by a short interview (endpoint, filters, enrichment, output, language).
   Schema: `gtm-brief-schema.md` in the `blitz-gtm-brainstorm` skill (`references/`), when installed.

   Done when endpoint, filters, enrichment, output, language and volume are all in hand.

2. **Gate the enums.** A brief that uses categorical enums needs `enums_verified: true`. Otherwise
   send the user to `blitz-gtm-brainstorm`, or validate now with its `scripts/pull_enums.sh`;
   without that skill, check each value against the Blitz docs normalization pages
   (`/guide/reference/normalization/`) or the public spec at https://api.blitz-api.ai/openapi. A
   keyword-only brief needs no gate.

   Done when `enums_verified` is `true` or the brief uses no enums.

3. **Detect the package manager.** `bash scripts/detect_pm.sh <python|typescript|javascript>` →
   Python: `uv` → `poetry` → `pip` (+venv). JS/TS: `bun` → `pnpm` → `yarn` → `npm`. The `run`
   command follows the brief's `language`: `python` runs `script.py`, `typescript` runs `script.ts`
   via bun/tsx, `javascript` runs `script.mjs` via bun/node.

   Done when you hold the install and run commands for the brief's language.

4. **Install and verify the SDK.** Install (`uv add blitz-api-py` / `bun add blitz-api-js` / pip /
   npm), then `bash scripts/verify_sdk.sh <python|typescript|javascript>`. If install or import
   fails, show the exact error and the install command and **stop**: fixing the environment comes
   next, and the script keeps the SDK as its client.

   Done when `verify_sdk.sh` reports the SDK installed.

5. **Generate the script** from [references/script-templates.md](references/script-templates.md)
   in the brief's `language`: `python` → `script.py`, `typescript` → `script.ts`, `javascript` →
   `script.mjs` (the TypeScript template without type annotations).
   - `volume.exceeds_ceiling: false` → **single-population** template (SDK auto-paginates).
   - `volume.exceeds_ceiling: true` → **partitioned** template: loop the `partition_plan`
     segments, collect all pages per segment, union, and **dedupe by `output.dedupe_key`**.

   Map the brief's filters into the SDK call; method surface and client config:
   [references/sdk-reference.md](references/sdk-reference.md).

   Done when every filter and enum value in the brief appears verbatim in the call and, for
   `exceeds_ceiling: true`, every `partition_plan` segment is looped.

6. **Safety and errors.** Read the key from `BLITZ_API_KEY` (`.env`, listed in `.gitignore`), add a
   `/v2/account/key-info` preflight, and cover the cases in
   [references/error-handling.md](references/error-handling.md): `found == false`, empty results,
   `422`s, and the US-only, paid-plan phone caveat.

   Done when the script handles every row of the cases table in `error-handling.md`.

7. **Tell the user how to run it** — Python: `uv run script.py`; TypeScript: `bun run script.ts`
   (or `npx tsx script.ts` without bun); JavaScript: `bun run script.mjs` (or `node script.mjs`) —
   and which env var to set (`BLITZ_API_KEY`).

   Done when the run command and `BLITZ_API_KEY` are both named.
