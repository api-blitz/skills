# Security Policy

Thanks for helping keep Blitz API users safe.

## Supported versions

Only the latest release of this repository (the `main` branch and the most recent `blitz-api-skills` plugin version in [`.claude-plugin/plugin.json`](./.claude-plugin/plugin.json)) receives security fixes. Update with the same command you used to install, for example `npx skills@latest add api-blitz/skills`.

## What's in scope

This repository holds agent skills, the shell scripts they bundle, and the plugin and MCP client configs. Reports about any of these are in scope:

- **Bundled scripts** (`skills/*/*/scripts/`) with command injection, unsafe temp-file handling, secrets written to disk or printed to the terminal, or other unsafe behavior.
- **Plugin and MCP configs** (`.mcp.json`, `mcp.cursor.json`, `.claude-plugin/`, `.cursor-plugin/`) that point to the wrong endpoint or ship a credential.
- **Committed secrets**: any API key, token, or credential in the repository or its history.

## What's out of scope

- The hosted Blitz API and MCP server (`https://api.blitz-api.ai`) are operated by Blitz API, not by this repository. Report vulnerabilities in the service itself through the [Blitz contact page](https://www.blitz-api.ai/contact) and say it is a security report.
- Vulnerabilities in third-party agents, SDKs, or tools (Claude Code, Cursor, the skills.sh installer, `blitz-api-py`, `blitz-api-js`). Report those to their maintainers.

## How to report

Please **do not open a public issue or pull request** for a suspected vulnerability.

Report privately through GitHub: go to the [Security tab](https://github.com/api-blitz/skills/security) of this repository and choose **Report a vulnerability**. If that option is not available, use the [Blitz contact page](https://www.blitz-api.ai/contact), mark the message as a security report. Do not include exploit details in the first message.

Include as much of the following as you can:

- The affected file or skill, and the version or commit.
- Steps to reproduce, or a proof of concept.
- The impact you expect, and which agent or environment you tested in.

## What to expect

We will acknowledge your report, confirm whether we can reproduce it, and keep you updated until it is fixed. We will credit you in the fix unless you prefer to stay anonymous. Please give us a reasonable chance to ship a fix before you disclose publicly.

## If you leaked a Blitz API key

If a key was committed, pasted into an agent session, or otherwise exposed, revoke it and create a new one in your Blitz account right away. Removing the commit is not enough, because the key stays in git history and any caches. Blitz API keys belong in the environment (`BLITZ_API_KEY`) or in your own local MCP config, never in a committed file.
