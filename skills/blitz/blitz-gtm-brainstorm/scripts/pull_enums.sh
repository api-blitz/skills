#!/usr/bin/env bash
# Pull Blitz's canonical, case-sensitive enum values LIVE from the docs.
#
# Why: these values silently return 0 results on any mismatch, and the dataset changes,
# so never trust a hardcoded snapshot. Re-pull on every brief. If offline, fall back to
# references/enums-snapshot.md and re-verify before any real run.
#
# Usage:
#   bash pull_enums.sh                 # all enum pages
#   bash pull_enums.sh industries      # one page
#   bash pull_enums.sh | grep -i "software"   # find an exact value
set -uo pipefail

BASE="https://docs.blitz-api.ai/guide/reference/normalization"
PAGES=("industries" "job-levels" "companies" "geography" "filters" "urls")
[ "$#" -gt 0 ] && PAGES=("$@")

ok=0
for page in "${PAGES[@]}"; do
  echo "===================== ${page} ====================="
  if curl -fsSL "${BASE}/${page}.md" 2>/dev/null; then
    ok=1
  else
    echo "WARN: could not fetch ${page}.md (offline?) — use references/enums-snapshot.md"
  fi
  echo
done

if [ "$ok" != "1" ]; then
  echo "All live pulls failed. Fall back to references/enums-snapshot.md and re-verify." >&2
  exit 1
fi
