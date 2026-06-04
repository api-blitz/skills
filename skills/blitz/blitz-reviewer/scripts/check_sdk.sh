#!/usr/bin/env bash
# Compare the installed Blitz SDK version against the latest published release.
# Run from the user's project root (the install it checks is the project/venv one).
# Emits: installed=<v|>, latest=<v|>, status=up-to-date|outdated|not-installed|unknown, and a
# fix= line when action is needed. Warns (does not hard-fail) when offline / jq is absent.
# Usage: bash check_sdk.sh <python|javascript>
set -uo pipefail

LANG_ARG="${1:-}"
have_jq=1; command -v jq >/dev/null 2>&1 || have_jq=0
fetch() { curl -fsSL --max-time 10 "$1" 2>/dev/null; }

case "$LANG_ARG" in
  python|py)
    pkg=blitz-api-py
    installed=""
    if command -v uv >/dev/null 2>&1 && uv pip show "$pkg" >/dev/null 2>&1; then
      installed="$(uv pip show "$pkg" 2>/dev/null | awk -F': ' '/^Version/{print $2; exit}')"
    elif command -v pip3 >/dev/null 2>&1 && pip3 show "$pkg" >/dev/null 2>&1; then
      installed="$(pip3 show "$pkg" 2>/dev/null | awk -F': ' '/^Version/{print $2; exit}')"
    elif python3 -c "import blitz_api" >/dev/null 2>&1; then
      installed="$(python3 -c "import blitz_api; print(getattr(blitz_api,'__version__',''))" 2>/dev/null)"
    fi
    [ "$have_jq" -eq 1 ] && latest="$(fetch "https://pypi.org/pypi/${pkg}/json" | jq -r '.info.version // empty' 2>/dev/null)" || latest=""
    upgrade="uv add ${pkg}@latest   (or: pip install -U ${pkg})"
    install="uv add ${pkg}   (or: pip install ${pkg})"
    ;;
  javascript|js|typescript|ts)
    pkg=blitz-api-js
    installed=""
    if npm ls "$pkg" >/dev/null 2>&1; then
      installed="$(npm ls "$pkg" 2>/dev/null | grep -oE "${pkg}@[0-9][0-9A-Za-z.-]*" | head -1 | cut -d@ -f2)"
    elif command -v bun >/dev/null 2>&1 && bun pm ls 2>/dev/null | grep -q "$pkg"; then
      installed="$(bun pm ls 2>/dev/null | grep -oE "${pkg}@[0-9][0-9A-Za-z.-]*" | head -1 | cut -d@ -f2)"
    fi
    latest=""
    [ "$have_jq" -eq 1 ] && latest="$(fetch "https://registry.npmjs.org/${pkg}/latest" | jq -r '.version // empty' 2>/dev/null)"
    [ -z "$latest" ] && command -v npm >/dev/null 2>&1 && latest="$(npm view "$pkg" version 2>/dev/null)"
    upgrade="bun add ${pkg}@latest   (or: npm install ${pkg}@latest)"
    install="bun add ${pkg}   (or: npm install ${pkg})"
    ;;
  *)
    echo "usage: check_sdk.sh <python|javascript>" >&2
    exit 2
    ;;
esac

echo "installed=${installed:-}"
echo "latest=${latest:-}"
if [ -z "${installed:-}" ]; then
  echo "status=not-installed"
  echo "fix=${install}"
elif [ -z "${latest:-}" ]; then
  echo "status=unknown   # could not reach the registry (offline?) — installed ${installed}"
elif [ "$installed" = "$latest" ]; then
  echo "status=up-to-date"
else
  echo "status=outdated"
  echo "fix=${upgrade}"
fi
