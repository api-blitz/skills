#!/usr/bin/env bash
# Confirm the official Blitz SDK is installed and print its version.
# Exit 0 + version when present; exit 1 + install hint when missing.
# Usage: bash verify_sdk.sh <python|typescript>
set -uo pipefail

LANG_ARG="${1:-}"
case "$LANG_ARG" in
  python|py)
    if command -v uv >/dev/null 2>&1 && uv pip show blitz-api-py >/dev/null 2>&1; then
      uv pip show blitz-api-py | awk -F': ' '/^Version/{print "blitz-api-py " $2}'
    elif python3 -c "import blitz_api" >/dev/null 2>&1; then
      python3 -c "import blitz_api; print('blitz-api-py', getattr(blitz_api, '__version__', '(version unknown)'))"
    else
      echo "blitz-api-py: NOT INSTALLED — run: uv add blitz-api-py   (or: pip install blitz-api-py)"
      exit 1
    fi
    ;;
  typescript|ts|javascript|js)
    if npm ls blitz-api-js >/dev/null 2>&1; then
      npm ls blitz-api-js 2>/dev/null | grep blitz-api-js | head -1
    elif command -v bun >/dev/null 2>&1 && bun pm ls 2>/dev/null | grep -q blitz-api-js; then
      bun pm ls 2>/dev/null | grep blitz-api-js | head -1
    else
      echo "blitz-api-js: NOT INSTALLED — run: bun add blitz-api-js   (or: npm install blitz-api-js)"
      exit 1
    fi
    ;;
  *)
    echo "usage: verify_sdk.sh <python|typescript>" >&2
    exit 2
    ;;
esac
