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
