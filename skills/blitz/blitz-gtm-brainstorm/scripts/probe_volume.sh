#!/usr/bin/env bash
# Probe how big a Blitz search population is BEFORE building the script, so the brief knows
# whether to partition (anti-truncation). Forces max_results:1 — it counts, it does not collect.
#
# Needs: BLITZ_API_KEY in the env, plus curl and jq.
# Usage:
#   echo '<request-json>' | BLITZ_API_KEY=sk_... bash probe_volume.sh /v2/search/people
#   echo '{"company":{"industry":{"include":["Software Development"]}},"people":{"job_level":["VP"]}}' \
#     | BLITZ_API_KEY=sk_... bash probe_volume.sh /v2/search/people
set -uo pipefail

ENDPOINT="${1:-}"
if [ -z "$ENDPOINT" ]; then
  echo "usage: echo BODY_JSON | BLITZ_API_KEY=... probe_volume.sh /v2/search/{people|companies|employee-finder}" >&2
  exit 2
fi
: "${BLITZ_API_KEY:?set BLITZ_API_KEY in your env (.env) first}"
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

BODY="$(cat)"
[ -n "$BODY" ] || { echo "no request JSON on stdin" >&2; exit 2; }

# Force a count-only call (page 1, one result).
BODY="$(printf '%s' "$BODY" | jq '. + {max_results: 1, page: 1}')" \
  || { echo "stdin was not valid JSON" >&2; exit 2; }

RESP="$(curl -fsS -X POST "https://api.blitz-api.ai${ENDPOINT}" \
  -H "x-api-key: ${BLITZ_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY")" || { echo "probe request failed (network / auth / plan?)" >&2; exit 1; }

# total_results: Find People & Company Search. total_pages: Employee Finder.
echo "$RESP" | jq '{
  total_results: .total_results,
  total_pages:   .total_pages,
  cursor:        .cursor,
  results_length: ((.results // []) | length)
}'
