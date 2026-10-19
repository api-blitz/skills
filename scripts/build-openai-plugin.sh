#!/usr/bin/env bash
# Build the ZIP you upload at https://platform.openai.com/plugins.
# Usage: scripts/build-openai-plugin.sh [output.zip]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-${TMPDIR:-/tmp}/blitz-api-plugin.zip}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac

# The OpenAI portal wants skills as direct children of skills/, so flatten
# skills/blitz/<skill>/ here instead of shipping the bucket folder.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
PKG="$STAGE/blitz-api"

version="$(jq -r .version "$REPO/.claude-plugin/plugin.json")"
for manifest in .codex-plugin/plugin.json plugin.json; do
  got="$(jq -r .version "$REPO/openai-plugin/$manifest")"
  if [ "$got" != "$version" ]; then
    echo "openai-plugin/$manifest is at $got but .claude-plugin/plugin.json is at $version" >&2
    exit 1
  fi
done

mkdir -p "$PKG/skills"
cp -R "$REPO/openai-plugin/." "$PKG/"
cp "$REPO/LICENSE" "$PKG/"
for skill in "$REPO"/skills/blitz/*/; do
  cp -R "$skill" "$PKG/skills/$(basename "$skill")"
done

rm -f "$OUT"
(cd "$STAGE" && zip -qrD "$OUT" blitz-api -x '*.DS_Store')
echo "$OUT"
