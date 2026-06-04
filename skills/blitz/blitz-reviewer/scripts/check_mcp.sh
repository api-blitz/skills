#!/usr/bin/env bash
# Detect whether the Blitz MCP server is configured for the local AI coding agent.
# MCP config lives in different places per agent; this scans the common ones plus any agent CLI
# that can list servers. The MOST reliable signal, though, is whether THIS agent already exposes
# Blitz MCP tools — check that first (this script is the fallback). Emits mcp=installed|missing.
# Always exits 0 — the value carries the status. Usage: bash check_mcp.sh
set -uo pipefail

found=0

# 1. Any agent CLI that can list MCP servers (extend as more agents ship one).
if command -v claude >/dev/null 2>&1; then
  claude mcp list 2>/dev/null | grep -qi blitz && found=1
fi

# 2. Known MCP config files across agents (project + user scope). Grep for a blitz server.
configs=(
  "./.mcp.json" "./mcp.json" "./.cursor/mcp.json" "./.vscode/mcp.json"             # project scope
  "$HOME/.claude.json"                                                             # Claude Code
  "$HOME/.cursor/mcp.json"                                                         # Cursor
  "$HOME/.codeium/windsurf/mcp_config.json"                                        # Windsurf
  "$HOME/.codex/config.toml"                                                       # Codex
  "$HOME/.continue/config.json"                                                    # Continue / Cline
  "$HOME/.config/zed/settings.json"                                                # Zed
  "$HOME/Library/Application Support/Claude/claude_desktop_config.json"            # Claude Desktop (macOS)
  "$HOME/.config/Claude/claude_desktop_config.json"                               # Claude Desktop (Linux)
)
for f in "${configs[@]}"; do
  [ -f "$f" ] || continue
  grep -qi blitz "$f" 2>/dev/null && found=1
done

if [ "$found" -eq 1 ]; then
  echo "mcp=installed"
else
  echo "mcp=missing"
  echo "hint=add the Blitz HTTP MCP (url https://docs.blitz-api.ai/mcp) to your agent's MCP config, then restart. Per-agent steps: https://docs.blitz-api.ai/guide/integrations/MCP"
fi
