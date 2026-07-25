#!/usr/bin/env bash
#
# Wire Claude Code to the Obsidian vault: Seekstone MCP (user scope) + scribe hooks.
# Idempotent. The scribe hook script itself lives in the project repo
# (setup-ai-native-dev-env/scribe/claude-code/). This installs the config that points at it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="${SEEKSTONE_VAULT:-$HOME/Documents/obsidian-vault}"
SETTINGS="$HOME/.claude/settings.json"
TRACKED_SETTINGS="$SCRIPT_DIR/claude-code-settings.json"

command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }
command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 1; }

# 1. MCP server (user scope = all projects). Remove first so re-runs don't error.
claude mcp remove obsidian --scope user 2>/dev/null || true
claude mcp add obsidian --scope user --env "SEEKSTONE_VAULT=$VAULT" -- npx -y seekstone

# 2. Hooks: merge tracked hooks into ~/.claude/settings.json (preserve any existing keys).
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
tmp="$(mktemp)"
jq -s '.[0] * .[1]' "$SETTINGS" "$TRACKED_SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "Claude Code wired:"
echo "  MCP:   obsidian (Seekstone) -> $VAULT"
echo "  hooks: Stop + SessionEnd -> scribe (project repo)"
claude mcp list 2>/dev/null | grep obsidian || true
