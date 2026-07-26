#!/usr/bin/env bash
#
# Wire Claude Code to the Obsidian vault: Seekstone MCP (user scope) + scribe Stop hook.
# Idempotent. Generates the hook config from $HOME at install time (portable across machines),
# so no absolute paths are committed. The scribe script lives in the project repo.
set -euo pipefail

VAULT="${SEEKSTONE_VAULT:-$HOME/Documents/obsidian-vault}"
PROJECT_DIR="${SCRIBE_PROJECT_DIR:-$HOME/Documents/code/setup-ai-native-dev-env}"
SETTINGS="$HOME/.claude/settings.json"
SCRIBE_PY="$PROJECT_DIR/scribe/claude-code/claude_code_scribe.py"
UV="$(command -v uv || echo /opt/homebrew/bin/uv)"

command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }
command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 1; }
[ -f "$SCRIBE_PY" ] || { echo "scribe script missing: $SCRIBE_PY (clone the project repo there)" >&2; exit 1; }

# 1. MCP server (user scope = all projects). Remove first so re-runs don't error.
claude mcp remove obsidian --scope user 2>/dev/null || true
claude mcp add obsidian --scope user --env "SEEKSTONE_VAULT=$VAULT" -- npx -y seekstone

# 2. Hooks: generate the Stop-hook block for THIS machine and merge into settings.json.
#    Runs the scribe via `uv run` — uv self-manages the Python interpreter (PEP 723), so this
#    works with no system python3 on PATH.
hooks_block="$(cat <<JSON
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "$UV", "args": ["run", "--script", "$SCRIBE_PY"], "async": true } ] }
    ]
  }
}
JSON
)"
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
tmp="$(mktemp)"
jq -s '.[0] * .[1]' "$SETTINGS" <(printf '%s' "$hooks_block") > "$tmp" && mv "$tmp" "$SETTINGS"

echo "Claude Code wired:"
echo "  MCP:   obsidian (Seekstone) -> $VAULT"
echo "  hook:  Stop -> $SCRIBE_PY"
claude mcp list 2>/dev/null | grep obsidian || true
