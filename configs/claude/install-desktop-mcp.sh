#!/usr/bin/env bash

# Merge the tracked Obsidian (Seekstone) MCP server block into Claude Desktop's config.
#
# Claude Desktop rewrites ~/Library/Application Support/Claude/claude_desktop_config.json
# on launch (expanding "preferences"), so we must edit while the app is quit and merge
# rather than overwrite. This preserves whatever preferences the app has written.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
VAULT="${SEEKSTONE_VAULT:-$HOME/Documents/obsidian-vault}"
NPX="$(command -v npx || echo /opt/homebrew/bin/npx)"

command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

# Quit Claude Desktop if running, so our write is not clobbered.
if pgrep -x Claude >/dev/null; then
  osascript -e 'quit app "Claude"' 2>/dev/null || true
  for _ in 1 2 3 4 5; do pgrep -x Claude >/dev/null || break; sleep 1; done
fi

mkdir -p "$(dirname "$CFG")"
[ -f "$CFG" ] || echo '{}' > "$CFG"

# Generate the MCP block for THIS machine (portable; no committed absolute paths).
block="$(cat <<JSON
{ "mcpServers": { "obsidian": { "command": "$NPX", "args": ["-y", "seekstone"], "env": { "SEEKSTONE_VAULT": "$VAULT" } } } }
JSON
)"

# Deep-merge: existing config first, generated mcpServers block second (block wins on conflict).
tmp="$(mktemp)"
jq -s '.[0] * .[1]' "$CFG" <(printf '%s' "$block") > "$tmp" && mv "$tmp" "$CFG"

echo "Merged Obsidian MCP into $CFG (vault: $VAULT). Launch Claude Desktop to connect."
