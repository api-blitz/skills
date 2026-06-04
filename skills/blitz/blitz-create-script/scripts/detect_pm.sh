#!/usr/bin/env bash
# Pick the best package manager + commands for the brief's language.
# Python -> uv, else poetry, else pip (+venv). JS/TS -> bun, else pnpm, else yarn, else npm.
# typescript runs via bun/tsx (script.ts); javascript runs via bun/node (script.mjs).
# Usage: bash detect_pm.sh <python|typescript|javascript>
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
    # Same JS-ecosystem package managers for both; only the run command differs by choice:
    #   TypeScript -> script.ts  (needs a TS runtime: bun, or tsx under node)
    #   JavaScript -> script.mjs (plain ESM: bun, or node directly — .mjs needs no package.json "type")
    case "$LANG_ARG" in typescript|ts) ext=ts ;; *) ext=mjs ;; esac

    if command -v bun >/dev/null 2>&1; then
      mgr=bun;  add="bun add blitz-api-js"
    elif command -v pnpm >/dev/null 2>&1; then
      mgr=pnpm; add="pnpm add blitz-api-js"
    elif command -v yarn >/dev/null 2>&1; then
      mgr=yarn; add="yarn add blitz-api-js"
    else
      mgr=npm;  add="npm install blitz-api-js"
    fi

    if [ "$mgr" = bun ]; then
      run="bun run script.${ext}   # or: bun --env-file=.env run script.${ext}"
    elif [ "$ext" = ts ]; then
      run="npx tsx script.ts   # TS runtime; for .env: node --env-file=.env --import tsx script.ts (needs tsx installed)"
    else
      run="node --env-file=.env script.mjs   # plain JS, Node 20.6+ (or: node script.mjs with the env exported)"
    fi

    echo "manager=$mgr"
    echo "add=$add"
    echo "run=$run"
    ;;
  *)
    echo "usage: detect_pm.sh <python|typescript|javascript>" >&2
    exit 2
    ;;
esac
