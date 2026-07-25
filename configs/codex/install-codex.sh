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
CODEX_BIN="/Applications/ChatGPT.app/Contents/Resources/codex"
CODEX_HOME="$HOME/.codex"
TRACKED_HOOKS="$SCRIPT_DIR/hooks.json"

[ -x "$CODEX_BIN" ] || { echo "Codex binary not found at $CODEX_BIN (install ChatGPT.app)" >&2; exit 1; }

# 1. Put codex on PATH.
ln -sf "$CODEX_BIN" /opt/homebrew/bin/codex
echo "Linked codex -> $CODEX_BIN"

# 2. MCP server (global). Remove first so re-runs don't error.
"$CODEX_BIN" mcp remove obsidian 2>/dev/null || true
"$CODEX_BIN" mcp add obsidian --env "SEEKSTONE_VAULT=$VAULT" -- npx -y seekstone

# 3. Scribe Stop hook.
mkdir -p "$CODEX_HOME"
cp "$TRACKED_HOOKS" "$CODEX_HOME/hooks.json"

echo "Codex wired:"
echo "  MCP:   obsidian (Seekstone) -> $VAULT"
echo "  hook:  Stop -> scribe (project repo)"
echo
echo "NEXT (interactive, one-time):"
echo "  1. Log in:      codex login"
echo "  2. Trust hook:  run 'codex', then '/hooks' and trust the Obsidian scribe hook."
echo "     (Codex re-flags a hook whenever its script hash changes.)"
