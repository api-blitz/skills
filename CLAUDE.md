Skills are organized into bucket folders under `skills/`:

- `blitz/` — skills that wrap [Blitz API](https://blitz-api.ai) directly (Waterfall ICP, People/Company Search, enrichment, integration recipes)
- `gtm/` — general go-to-market workflows (lead-finding scripts, outreach, content, sales motions, analytics, lifecycle automation, and the engineering that powers them)
- `productivity/` — general workflow tools, not GTM-specific

Every skill must have a reference in the top-level `README.md` and an entry in `.claude-plugin/plugin.json`.

Each skill entry in the top-level `README.md` must link the skill name to its `SKILL.md`.

Each bucket folder has a `README.md` that lists every skill in the bucket with a one-line description, with the skill name linked to its `SKILL.md`.
