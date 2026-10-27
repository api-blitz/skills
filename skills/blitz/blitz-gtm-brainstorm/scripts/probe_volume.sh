#!/usr/bin/env bash
# Probe how big a Blitz search population is BEFORE building the script, so the brief knows
# whether to partition (anti-truncation). Forces max_results:1 — it counts, it does not collect
# (and so spends one record, since a search bills 1 record per result returned).
#
# Reads `total_results` (people / companies / jobs searches) or `total_pages` (employee-finder).
# The TAM endpoints (company/tam-by-people, company/tam-by-jobs) return no total, so they cannot be
# sized this way — page their cursor instead. Waterfall ICP is never partitioned, so never probe it.
#
# Needs: BLITZ_API_KEY in the env, plus curl and jq.
# Usage:
#   echo '<request-json>' | BLITZ_API_KEY=sk_... bash probe_volume.sh /v2/search/people
#   echo '{"company":{"keywords":{"include":["devtools"]}},"people":{"job_title":{"include":["VP Engineering"]}}}' \
#     | BLITZ_API_KEY=sk_... bash probe_volume.sh /v2/search/people
set -uo pipefail

ENDPOINT="${1:-}"
if [ -z "$ENDPOINT" ]; then
  echo "usage: echo BODY_JSON | BLITZ_API_KEY=... probe_volume.sh /v2/search/{people|companies|employee-finder} | /v2/jobs/{search|company}" >&2
  exit 2
fi
: "${BLITZ_API_KEY:?set BLITZ_API_KEY in your env (.env) first}"
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

BODY="$(cat)"
[ -n "$BODY" ] || { echo "no request JSON on stdin" >&2; exit 2; }

case "$ENDPOINT" in
  /v2/company/tam-by-*)
    echo "$ENDPOINT returns no total_results — size it by paging the cursor until it is null." >&2
    exit 2 ;;
  /v2/search/waterfall-icp-keyword)
    echo "Waterfall ICP is a single ranked set, not a population — nothing to probe." >&2
    exit 2 ;;
esac

# Force a count-only call (one result). Only employee-finder is page-based: every /v2 endpoint
# rejects a field it does not define with a 422, so `page` must not be sent anywhere else.
if [ "$ENDPOINT" = "/v2/search/employee-finder" ]; then
  BODY="$(printf '%s' "$BODY" | jq '. + {max_results: 1, page: 1}')" \
    || { echo "stdin was not valid JSON" >&2; exit 2; }
else
  BODY="$(printf '%s' "$BODY" | jq '. + {max_results: 1}')" \
    || { echo "stdin was not valid JSON" >&2; exit 2; }
fi

# No -f: on a 4xx the JSON body (a 422 names the offending field) is the useful part.
RESP="$(curl -sS -X POST "https://api.blitz-api.ai${ENDPOINT}" \
  -H "x-api-key: ${BLITZ_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY")" || { echo "probe request failed (network?)" >&2; exit 1; }

# Every error body is {"success": false, "message": ...} (a 422 also lists errors[]).
if echo "$RESP" | jq -e '.success == false' >/dev/null 2>&1; then
  echo "probe rejected — fix the request or the key (a 422 lists each bad field in errors[]):" >&2
  echo "$RESP" | jq . >&2
  exit 1
fi

# total_results: Find People, Company Search, jobs. total_pages: Employee Finder.
echo "$RESP" | jq '{
  total_results: .total_results,
  total_pages:   .total_pages,
  cursor:        .cursor,
  results_length: ((.results // []) | length)
}'
