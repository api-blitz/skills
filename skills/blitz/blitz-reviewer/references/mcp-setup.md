# Blitz MCP — detect, and push hard to install (any agent)

The Blitz MCP is the **most important** thing on the checklist. Installed, it lets the reviewer (and
every later Blitz task) validate request bodies and enum values against the **live** API schema and
docs instead of a point-in-time snapshot — far fewer silent "ran clean, returned nothing" bugs from
a renamed field or a miscased enum. Treat a missing MCP as a blocker worth a real nudge, not a footnote.

These skills run on **any coding agent** (Claude Code, Cursor, VS Code / Copilot, Windsurf, Codex,
Cline, Zed, claude.ai, …). The MCP server is identical everywhere — only *where you register it*
differs. Confirm the exact per-client steps at the docs link, since configs change.

- Docs (per-client steps): https://docs.blitz-api.ai/guide/integrations/MCP
- The server: name `blitz-api` · URL `https://docs.blitz-api.ai/mcp` · transport **HTTP** · no API key.

## Detect

1. **Your own tools first (most reliable, agent-independent).** If you — whichever agent you are —
   already expose Blitz MCP tools (names containing `blitz`, e.g. `search…blitz…`,
   `query_docs…blitz…`), the MCP is connected. Done.
2. **Fallback:** `bash scripts/check_mcp.sh` — scans the common per-agent MCP config files and any
   agent CLI that can list servers, grepping for a `blitz` entry. Prints `mcp=installed|missing`.

A config entry can exist without the tools being live (needs a restart), and tools can be live via a
GUI connector with no config file — so trust your available tools over the script when they disagree.

Once it's connected, **query it as the source of truth** for endpoints, request bodies, and enums
during checks 4–6 — recipes in [code-audit.md](code-audit.md). Don't validate code against memory.

## If it's missing — make the case, then add it for the user's agent

Tell the user plainly: *the MCP makes this review (and all their Blitz code) materially more
accurate — it's a one-minute, no-API-key add.* Then add it the way **their** agent expects. Work out
which agent you're running as and use the matching method:

- **CLI agents (e.g. Claude Code):** run the agent's add command —
  `claude mcp add --transport http blitz-api https://docs.blitz-api.ai/mcp`.
- **Config-file agents (Cursor, VS Code, Windsurf, Cline, Zed, …):** add the HTTP server to that
  agent's MCP config (with the user's OK). The two shapes that cover most agents:
  ```json
  // most agents (Cursor, Windsurf, Claude Desktop): an mcpServers map keyed by url
  { "mcpServers": { "blitz-api": { "url": "https://docs.blitz-api.ai/mcp" } } }
  ```
  ```json
  // VS Code: a servers map with an explicit transport type
  { "servers": { "blitz-api": { "type": "http", "url": "https://docs.blitz-api.ai/mcp" } } }
  ```
- **GUI connectors (claude.ai, ChatGPT, …):** add a custom connector and paste
  `https://docs.blitz-api.ai/mcp`.
- **stdio-only agents (older Codex / Claude Desktop):** wrap the HTTP server with `mcp-remote` —
  ```json
  { "mcpServers": { "blitz-api": { "command": "npx", "args": ["-y", "mcp-remote", "https://docs.blitz-api.ai/mcp"] } } }
  ```

**Restart the agent after adding it** so the tools load. If you're unsure which config a given agent
uses, send the user to the docs link above (it lists each client) rather than guessing.

## If the user still declines

Continue the review with the fallback sources and **mark check 1 as ⚠ (degraded confidence)** in
the report — bodies/enums are then validated against the docs and the bundled snapshots, which lag
the live schema:

- Bodies/methods: [../../blitz-create-script/references/sdk-reference.md](../../blitz-create-script/references/sdk-reference.md)
  and [../../blitz-gtm-brainstorm/references/endpoint-decision.md](../../blitz-gtm-brainstorm/references/endpoint-decision.md)
- Enums: [../../blitz-gtm-brainstorm/references/enums.json](../../blitz-gtm-brainstorm/references/enums.json)
  (or search live with `../../blitz-gtm-brainstorm/scripts/pull_enums.sh search <enum> "<value>"`)
