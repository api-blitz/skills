#!/usr/bin/env bash
# Compare the installed Blitz skills plugin version against the latest on api-blitz/skills.
# Emits: local=<v|unknown>, latest=<v|>, status=up-to-date|outdated|unknown, + a fix= line.
# Warns (does not hard-fail) when offline or when no local plugin.json can be found.
# Usage: bash check_skills.sh
set -uo pipefail

have_jq=1; command -v jq >/dev/null 2>&1 || have_jq=0
fetch() { curl -fsSL --max-time 10 "$1" 2>/dev/null; }

# Read .version from a plugin.json on stdin (jq if available, else a grep fallback).
ver_from_json() {
  if [ "$have_jq" -eq 1 ]; then
    jq -r '.version // empty' 2>/dev/null
  else
    grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | grep -oE '"[^"]+"$' | tr -d '"'
  fi
}

# local: walk up from this script's dir to find .claude-plugin/plugin.json.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
local_ver=""; d="$DIR"
for _ in 1 2 3 4 5 6; do
  if [ -f "$d/.claude-plugin/plugin.json" ]; then
    local_ver="$(ver_from_json < "$d/.claude-plugin/plugin.json")"
    break
  fi
  [ "$d" = "/" ] && break
  d="$(dirname "$d")"
done

# latest: GitHub default-branch plugin.json (try main, then master).
latest=""
for br in main master; do
  raw="$(fetch "https://raw.githubusercontent.com/api-blitz/skills/${br}/.claude-plugin/plugin.json")"
  if [ -n "$raw" ]; then
    latest="$(printf '%s' "$raw" | ver_from_json)"
    [ -n "$latest" ] && break
  fi
done

echo "local=${local_ver:-unknown}"
echo "latest=${latest:-}"
if [ -z "$latest" ]; then
  echo "status=unknown   # could not reach GitHub (offline?)"
elif [ -z "$local_ver" ]; then
  echo "status=unknown   # no local plugin.json found to compare"
  echo "fix=npx skills@latest add api-blitz/skills"
elif [ "$local_ver" = "$latest" ]; then
  echo "status=up-to-date"
else
  echo "status=outdated"
  echo "fix=npx skills@latest add api-blitz/skills   # then re-pick the skills to refresh"
fi
