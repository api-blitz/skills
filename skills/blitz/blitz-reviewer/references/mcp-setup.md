# Blitz MCP — detect it, recommend it, add it (any agent)

The Blitz MCP is the first thing on the checklist. Connected, it gives the reviewer (and every later
Blitz task) the live tool schemas, the changelog and the docs, so request bodies and enum values are
validated against what Blitz serves now instead of a point-in-time snapshot — fewer `422`s and
silently-empty searches from a renamed field, a miscased enum, or a bad filter value. Without it the
review still runs, at lower confidence.

- Docs (per-client steps, kept current): https://docs.blitz-api.ai/guide/integrations/MCP
- The server: name `blitz-api` · URL `https://api.blitz-api.ai/mcp` · transport **HTTP** · auth
  **OAuth** (sign in with the Blitz account) or an `x-api-key` header (an API key goes in
  `x-api-key`; `Authorization: Bearer` takes OAuth access tokens only).
- Its `docs_*` tools read the Blitz docs and use no records. Its API tools (`people_*`, `company_*`,
  `job_*`) call the Blitz API and spend records, so a review leaves them uncalled.
- A **docs-only** server also exists — `https://docs.blitz-api.ai/mcp`, no sign-in, no records,
  docs search/read only. That covers the docs lookups of a review, so it suits someone who isn't
  ready to connect an account; the main server includes the same `docs_*` tools.

## Detect

1. **Your own tools first (most reliable, agent-independent).** If you — whichever agent you are —
   already expose Blitz MCP tools (`docs_search`, `docs_read`, or the `people_*` / `company_*` /
   `job_*` API tools, usually prefixed with the server name), the MCP is connected. Done.
2. **Fallback:** `bash scripts/check_mcp.sh` — scans the common per-agent MCP config files and any
   agent CLI that can list servers, grepping for a `blitz` entry. Prints `mcp=installed|missing`.

A config entry can exist without the tools being live (needs a restart or a sign-in), and tools can
be live via a GUI connector with no config file — so when they disagree, trust your available tools
over the script.

## If it's missing — recommend it, then offer to add it

Tell the user plainly: *the MCP makes this review (and their Blitz code in general) more accurate,
and takes about a minute to add. Sign-in is OAuth, or an API key in the `x-api-key` header.* Then
offer to add it the way **their** agent expects, with the user's OK. The docs page above lists the
current steps for Claude, Claude Code, Cursor, VS Code, Codex, Grok, ChatGPT and any other
HTTP-capable client (append `.md` to the URL for plain text). The Claude Code and Grok *plugins*
(`blitz-api-skills@blitz-api`, `grok plugin install api-blitz/skills --trust`) install the skills and
this MCP server together.

Prefer OAuth. A user who prefers an API key adds it as an `x-api-key` header in their own local
config, kept out of committed files and out of output.

**Restart the agent after adding it** and finish the sign-in prompt, so the tools load.

## If the user declines

Continue the review on the public sources (`code-audit.md` → Without the MCP) and **mark check 1 as
⚠ (degraded confidence)** in the report: bodies and enums are then validated against the public
OpenAPI and docs, which can lag the changelog.
