# Architecture Decision Records

Numbered records (`NNNN-kebab-case-title.md`) capturing decisions about how these skills are designed and how they hang together.

Use ADRs for anything that:

- shapes the contract between skills (e.g. what one skill is allowed to assume another has produced),
- shapes the contract between skills and the user's environment (e.g. which CRMs, analytics stacks, or content surfaces are first-class),
- documents a non-obvious trade-off a future maintainer would otherwise re-litigate.

If you're deliberately rejecting a feature request, write a `.out-of-scope/` entry instead — ADRs are for what we _are_ building, not what we won't.
