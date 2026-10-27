<!-- mcp-name: ai.blitz-api/b2b-data -->
# Skills for Real GTM

This repo is the home of the **[BlitzAPI MCP server](#blitz-mcp-server)**, a hosted remote server that gives agents B2B data: search and enrich companies and people, verified work emails, US phone numbers, job postings, and the live Blitz docs. It also holds the **[Blitz agent skills](#quickstart-30-second-setup)**.

[![skills.sh](https://skills.sh/b/api-blitz/skills)](https://skills.sh/api-blitz/skills)

Agent skills for going to market with [Blitz API](https://www.blitz-api.ai) — lead-finding scripts, outreach, content, analytics, lifecycle automation, and the engineering that powers them.

[Website](https://www.blitz-api.ai) · [Docs](https://docs.blitz-api.ai) · [Connect Your AI (MCP)](https://docs.blitz-api.ai/guide/integrations/MCP)

These skills are designed to be small, easy to adapt, and composable. They work with any model. Hack around with them. Make them your own.

## Blitz MCP server

### What it does

Search and enrich B2B companies and people: verified work emails, US phone numbers, job postings. The server exposes one tool per Blitz API endpoint, plus tools to search and read the live Blitz docs, so an agent can look up how an endpoint works and call it in the same session. The plugin installs below ship it preconfigured.

| | |
| --- | --- |
| URL | `https://api.blitz-api.ai/mcp` |
| Transport | Streamable HTTP |
| Auth | OAuth (sign in with your Blitz account) — or an `x-api-key` header |
| Registry name | `ai.blitz-api/b2b-data` ([MCP Registry](https://registry.modelcontextprotocol.io/v0.1/servers?search=ai.blitz-api)) |

The committed configs ([`.mcp.json`](./.mcp.json) for Claude Code and Grok, [`mcp.cursor.json`](./mcp.cursor.json) for Cursor) use OAuth and contain no secrets. If you prefer an API key, pass it as a header in your own local config and never commit it, for example `claude mcp add --transport http blitz-api https://api.blitz-api.ai/mcp --header "x-api-key: YOUR_API_KEY"`. Full per-agent setup: [Connect Your AI (MCP)](https://docs.blitz-api.ai/guide/integrations/MCP).

### Tools

| Family | Tool | What it does | Cost |
| --- | --- | --- | --- |
| `people_*` | `people_search` | Find people across companies by ICP filters (company firmographics plus person title, level, function, geo) | 1 record per result |
| | `people_enrich` | Full profile and career history from a LinkedIn URL | 1 record on success |
| | `people_employee_finder` | List the current employees of one company by level, function, and geo | 1 record per result |
| | `people_waterfall_icp` | Best-fit people at one company, found through ordered title tiers | 1 record per result |
| | `people_find_work_email` | Work email(s) from a LinkedIn URL | 1 record on success |
| | `people_find_phone` | Mobile and direct phone numbers from a LinkedIn URL (US numbers only) | 1 record on success |
| | `people_lookup_by_email` | Reverse lookup: the person behind an email address | 1 record on success |
| | `people_lookup_by_phone` | Reverse lookup: the person behind a phone number | 1 record on success |
| `company_*` | `company_search` | Find companies by firmographic filters (name, industry, type, size, geo) | 1 record per result |
| | `company_enrich` | Full firmographic record from a LinkedIn URL | 1 record |
| | `company_find_by_domain` | A company's LinkedIn URL from its web domain | 1 record |
| | `company_get_domain` | A company's web domain from its LinkedIn URL | 1 record on success |
| | `company_tam_by_jobs` | Target-account list from companies posting jobs that match your filters | 1 record per result |
| | `company_tam_by_people` | Target-account list from companies whose employees match a person-level ICP | 1 record per result |
| | `company_employees_by_country` | Headcount distribution by country | 1 record on success |
| | `company_employees_by_department` | Headcount distribution by department | 1 record on success |
| `job_*` | `job_search` | Search job postings across all companies | 1 record per result |
| | `job_search_by_company` | Search the job postings of one company | 1 record per result |
| `docs_*` | `docs_search` | Search the Blitz documentation | No records |
| | `docs_read` | Read or browse Blitz documentation pages | No records |
| Utilities | `account_key_info` | Plan, remaining records, and rate limits for your key | 0 records |
| | `util_changelog` | Blitz API changelog, newest first | 0 records |
| | `util_current_date` | Current date and time in a given timezone | 0 records |
| | `send_feedback` | Send a bug report, feature request, or other feedback to the Blitz team | — |

API tools draw on the records in your plan's allowance. Search tools bill per result returned (set `max_results` to control it); lookups and enrichments bill when they succeed. Request bodies and valid filter values come from the server itself, so ask your agent to run `docs_search` before building a query.

### Account and pricing

A Blitz account is required. Your client opens an OAuth sign-in on first use, so there is no API key to copy. Plans and pricing are on the [Blitz website](https://www.blitz-api.ai).

## Quickstart (30-second setup)

1. Run the skills.sh installer:

```bash
npx skills@latest add api-blitz/skills
```

2. Pick the skills you want, and which coding agents you want to install them on.

3. You're ready to go.

## Install by agent

The skills.sh installer above works for Claude Code, Codex, Cursor, and other Agent Skills-compatible agents. The options below also add the [Blitz MCP server](#blitz-mcp-server).

### VS Code (GitHub Copilot)

Add the MCP server with the VS Code CLI:

```bash
code --add-mcp '{"name":"blitz-api","type":"http","url":"https://api.blitz-api.ai/mcp"}'
```

Or add it to `.vscode/mcp.json` in your project:

```json
{ "servers": { "blitz-api": { "type": "http", "url": "https://api.blitz-api.ai/mcp" } } }
```

Start the server and sign in with your Blitz account when VS Code prompts.

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

## Layout

Skills live under `skills/`, grouped into buckets:

- **[Blitz](./skills/blitz/README.md)** — skills that wrap Blitz API directly (Waterfall ICP, People/Company Search, enrichment, integration recipes).
- **[GTM](./skills/gtm/README.md)** — general lead-finding scripts, outreach, content, sales motions, analytics, lifecycle automation, and the engineering that powers them.
- **[Productivity](./skills/productivity/README.md)** — general workflow tools, not GTM-specific.

[`openai-plugin/`](./openai-plugin) holds the listing metadata, icons, and MCP config for the ChatGPT and Codex plugin. Run `scripts/build-openai-plugin.sh` to build the ZIP you upload at [platform.openai.com/plugins](https://platform.openai.com/plugins). Its `version` fields must match `.claude-plugin/plugin.json`, and the script fails if they don't.

See [`CLAUDE.md`](./CLAUDE.md) for the governance rules each bucket follows, and [`CONTEXT.md`](./CONTEXT.md) for the shared language used across these skills.

## Reference

### Blitz

Skills that wrap [Blitz API](https://www.blitz-api.ai) directly — Waterfall ICP cascades, People Search, Company Search, enrichment, and integration recipes.

- **[blitz-gtm-brainstorm](./skills/blitz/blitz-gtm-brainstorm/SKILL.md)** — interview a GTM goal into a validated, enum-checked Blitz brief (endpoint choice, ICP filters, enrichment, volume estimate).
- **[blitz-create-script](./skills/blitz/blitz-create-script/SKILL.md)** — turn a GTM brief into a runnable, install-and-go Blitz SDK script with API-key safety, error handling, and pagination.
- **[blitz-reviewer](./skills/blitz/blitz-reviewer/SKILL.md)** — review a Blitz integration before you run it: MCP installed, SDK & skills current, correct methods/bodies/enums in your code, and per-endpoint RPS/records.

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

## Security

To report a vulnerability, see [`SECURITY.md`](./SECURITY.md). Please don't open a public issue for it.

## License

Repository: MIT (see [LICENSE](./LICENSE)). The hosted MCP service is operated by BlitzAPI.
