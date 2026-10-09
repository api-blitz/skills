# Skills for Real GTM

[![skills.sh](https://skills.sh/b/api-blitz/skills)](https://skills.sh/api-blitz/skills)

Agent skills for going to market with [Blitz API](https://blitz-api.ai) — lead-finding scripts, outreach, content, analytics, lifecycle automation, and the engineering that powers them.

These skills are designed to be small, easy to adapt, and composable. They work with any model. Hack around with them. Make them your own.

## Quickstart (30-second setup)

1. Run the skills.sh installer:

```bash
npx skills@latest add api-blitz/skills
```

2. Pick the skills you want, and which coding agents you want to install them on.

3. You're ready to go.

## Install by agent

The skills.sh installer above works for Claude Code, Codex, Cursor, and other Agent Skills-compatible agents. The options below also add the [Blitz MCP server](#blitz-mcp-server).

### Claude Code

Install the plugin (skills + MCP server as one managed install). Inside Claude Code:

```bash
/plugin marketplace add api-blitz/skills
/plugin install blitz-api-skills@blitz-api
```

Or from your shell:

```bash
claude plugin marketplace add api-blitz/skills
claude plugin install blitz-api-skills@blitz-api
```

Then run `/mcp`, select **blitz-api**, and sign in with your Blitz account.

### Grok

```bash
grok plugin install api-blitz/skills --trust
```

The first Blitz tool call opens OAuth in the browser.

### Cursor

Install the skills with the skills.sh installer above, and add the MCP server to `mcp.json` (Cmd/Ctrl + Shift + P → **Open MCP Settings**):

```json
{
  "mcpServers": {
    "blitz-api": {
      "url": "https://api.blitz-api.ai/mcp"
    }
  }
}
```

### Claude.ai and ChatGPT

Add `https://api.blitz-api.ai/mcp` as a custom connector (remote MCP server) and sign in with your Blitz account. In Claude.ai: **"+"** → **Manage Connectors** → **Add custom Connector**.

## Blitz MCP server

The plugin ships the hosted Blitz MCP server, which gives your agent the live Blitz docs (`docs_*`) and API tools (`people_*`, `company_*`, `job_*`).

| | |
| --- | --- |
| URL | `https://api.blitz-api.ai/mcp` |
| Transport | HTTP |
| Auth | OAuth (sign in with your Blitz account) — or an `x-api-key` header |

The committed configs ([`.mcp.json`](./.mcp.json) for Claude Code and Grok, [`mcp.cursor.json`](./mcp.cursor.json) for Cursor) use OAuth and contain no secrets. If you prefer an API key, pass it as a header in your own local config and never commit it, for example `claude mcp add --transport http blitz-api https://api.blitz-api.ai/mcp --header "x-api-key: YOUR_API_KEY"`. Full per-agent setup: [Connect Your AI (MCP)](https://docs.blitz-api.ai/guide/integrations/MCP).

## Layout

Skills live under `skills/`, grouped into buckets:

- **[Blitz](./skills/blitz/README.md)** — skills that wrap Blitz API directly (Waterfall ICP, People/Company Search, enrichment, integration recipes).
- **[GTM](./skills/gtm/README.md)** — general lead-finding scripts, outreach, content, sales motions, analytics, lifecycle automation, and the engineering that powers them.
- **[Productivity](./skills/productivity/README.md)** — general workflow tools, not GTM-specific.

See [`CLAUDE.md`](./CLAUDE.md) for the governance rules each bucket follows, and [`CONTEXT.md`](./CONTEXT.md) for the shared language used across these skills.

## Reference

### Blitz

Skills that wrap [Blitz API](https://blitz-api.ai) directly — Waterfall ICP cascades, People Search, Company Search, enrichment, and integration recipes.

- **[blitz-gtm-brainstorm](./skills/blitz/blitz-gtm-brainstorm/SKILL.md)** — interview a GTM goal into a validated, enum-checked Blitz brief (endpoint choice, ICP filters, enrichment, volume estimate).
- **[blitz-create-script](./skills/blitz/blitz-create-script/SKILL.md)** — turn a GTM brief into a runnable, install-and-go Blitz SDK script with API-key safety, error handling, and pagination.
- **[blitz-reviewer](./skills/blitz/blitz-reviewer/SKILL.md)** — review a Blitz integration before you run it: MCP installed, SDK & skills current, correct methods/bodies/enums in your code, and per-endpoint RPS/credits.

### GTM

General go-to-market work — lead-finding scripts, outreach, content, analytics, lifecycle automation, and the engineering that powers them.

<!-- Add entries here as skills land in `skills/gtm/`. -->

### Productivity

General workflow tools, not GTM-specific.

<!-- Add entries here as skills land in `skills/productivity/`. -->

## Contributing

When you add a skill:

1. Put it in the right bucket (`blitz/`, `gtm/`, or `productivity/`).
2. Add the skill to:
   - this `README.md` (under the matching section above), and
   - `.claude-plugin/plugin.json` (the `skills` array), and
   - the bucket's own `README.md`.
3. Link any non-obvious design decisions in `docs/adr/`.
4. If you deliberately rejected a feature request, document it in `.out-of-scope/`.
