#!/usr/bin/env bash
# Pick the best package manager + commands for the brief's language.
# Python -> uv, else poetry, else pip (+venv). JS/TS -> bun, else pnpm, else yarn, else npm.
# Usage: bash detect_pm.sh <python|typescript>
set -uo pipefail

LANG_ARG="${1:-}"
case "$LANG_ARG" in
  python|py)
    if command -v uv >/dev/null 2>&1; then
      echo "manager=uv"
      echo "add=uv add blitz-api-py"
      echo "run=uv run script.py"
    elif command -v poetry >/dev/null 2>&1; then
      echo "manager=poetry"
      echo "add=poetry add blitz-api-py"
      echo "run=poetry run python script.py"
    else
      echo "manager=pip"
      echo "add=python3 -m venv .venv && . .venv/bin/activate && pip install blitz-api-py"
      echo "run=python3 script.py   # after activating .venv"
    fi
    ;;
  typescript|ts|javascript|js)
    if command -v bun >/dev/null 2>&1; then
      echo "manager=bun"
      echo "add=bun add blitz-api-js"
      echo "run=bun run script.ts"
    elif command -v pnpm >/dev/null 2>&1; then
      echo "manager=pnpm"
      echo "add=pnpm add blitz-api-js"
      echo "run=node script.js   # or: node --env-file=.env script.js"
    elif command -v yarn >/dev/null 2>&1; then
      echo "manager=yarn"
      echo "add=yarn add blitz-api-js"
      echo "run=node script.js   # or: node --env-file=.env script.js"
    else
      echo "manager=npm"
      echo "add=npm install blitz-api-js"
      echo "run=node script.js   # or: node --env-file=.env script.js"
    fi
    ;;
  *)
    echo "usage: detect_pm.sh <python|typescript>" >&2
    exit 2
    ;;
esac
