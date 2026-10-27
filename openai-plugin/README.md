# Blitz API plugin for ChatGPT and Codex

This package brings the Blitz API hosted MCP server and three Blitz workflows to ChatGPT and Codex. The MCP connection uses OAuth; connect your Blitz account when prompted. No API keys or other credentials are included in this ZIP.

## Included workflows

- **blitz-gtm-brainstorm** — turns a goal into an endpoint choice, validated ICP filters, enrichment plan, output target, and volume estimate.
- **blitz-create-script** — generates a runnable Python, JavaScript, or TypeScript script using the official Blitz SDK.
- **blitz-reviewer** — checks a Blitz setup and integration against the connected MCP tools and reports findings before fixes.

The hosted MCP server is `https://api.blitz-api.ai/mcp`. Its OAuth and available tools are managed by Blitz. API searches or enrichment use records from your Blitz plan's allowance; the reviewer workflow is designed to use read-only checks.

## Upload

Upload `blitz-api-plugin.zip` in the OpenAI plugin upload flow. After installation, connect the Blitz API app when prompted.

## Source and license

Built from [api-blitz/skills](https://github.com/api-blitz/skills) under the MIT License. The original skill text and supporting files are included.
