#!/usr/bin/env bash
#
# Wire Codex to the Obsidian vault: Seekstone MCP + scribe Stop hook.
# Idempotent. The scribe hook script lives in the project repo
# (setup-ai-native-dev-env/scribe/codex/). This installs the config that points at it.
#
# Note: Codex ships its CLI bundled inside the ChatGPT.app (the standalone codex-app cask is
# deprecated upstream). We symlink that binary onto PATH.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="${SEEKSTONE_VAULT:-$HOME/Documents/obsidian-vault}"
PROJECT_DIR="${SCRIBE_PROJECT_DIR:-$HOME/Documents/code/setup-ai-native-dev-env}"
CODEX_BIN="/Applications/ChatGPT.app/Contents/Resources/codex"
CODEX_HOME="$HOME/.codex"
SCRIBE_PY="$PROJECT_DIR/scribe/codex/codex_scribe.py"
UV="$(command -v uv || echo /opt/homebrew/bin/uv)"

[ -x "$CODEX_BIN" ] || { echo "Codex binary not found at $CODEX_BIN (install ChatGPT.app)" >&2; exit 1; }
[ -f "$SCRIBE_PY" ] || { echo "scribe script missing: $SCRIBE_PY (clone the project repo there)" >&2; exit 1; }

# 1. Put codex on PATH.
ln -sf "$CODEX_BIN" /opt/homebrew/bin/codex
echo "Linked codex -> $CODEX_BIN"

# 2. MCP server (global). Remove first so re-runs don't error.
"$CODEX_BIN" mcp remove obsidian 2>/dev/null || true
"$CODEX_BIN" mcp add obsidian --env "SEEKSTONE_VAULT=$VAULT" -- npx -y seekstone

# 3. Scribe Stop hook — generated for THIS machine (portable, no committed absolute paths).
#    Runs via `uv run` so no system python3 is required.
mkdir -p "$CODEX_HOME"
cat > "$CODEX_HOME/hooks.json" <<JSON
{
  "description": "Obsidian scribe: log each turn to the knowledge base.",
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "$UV run --script \"$SCRIBE_PY\"", "timeout": 60 } ] }
    ]
  }
}
JSON

echo "Codex wired:"
echo "  MCP:   obsidian (Seekstone) -> $VAULT"
echo "  hook:  Stop -> scribe (project repo)"
echo
echo "NEXT (interactive, one-time):"
echo "  1. Log in:      codex login"
echo "  2. Trust hook:  run 'codex', then '/hooks' and trust the Obsidian scribe hook."
echo "     (Codex re-flags a hook whenever its script hash changes.)"
