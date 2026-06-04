#!/usr/bin/env bash
# Read Blitz API key health — valid, remaining credits, allowed RPS, allowed APIs.
# This is a FREE call (key-info): it spends no credits. Needs BLITZ_API_KEY in the env, plus
# curl and jq. The response carries no secret, so its fields are safe to print.
# Usage: BLITZ_API_KEY=sk_... bash check_key.sh
set -uo pipefail

: "${BLITZ_API_KEY:?set BLITZ_API_KEY in your env (.env) first}"
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

RESP="$(curl -fsS --max-time 15 "https://api.blitz-api.ai/v2/account/key-info" \
  -H "x-api-key: ${BLITZ_API_KEY}")" || { echo "key-info request failed (network / invalid key?)" >&2; exit 1; }

echo "$RESP" | jq '{
  valid:                    .valid,
  remaining_credits:        .remaining_credits,
  max_requests_per_seconds: .max_requests_per_seconds,
  allowed_apis:             .allowed_apis,
  active_plans:             .active_plans
}'
