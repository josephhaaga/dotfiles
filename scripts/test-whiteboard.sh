#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node --test "$DOTFILES/tests/whiteboard-context.test.mjs"

for profile in desktop enterprise server container; do
  data="{\"profile\":\"$profile\"}"
  rendered="$(chezmoi execute-template --source "$DOTFILES" --override-data "$data" \
    < "$DOTFILES/home/dot_config/opencode/opencode.json.tmpl")"
  managed="$(chezmoi managed --source "$DOTFILES" --override-data "$data")"
  if [ "$profile" = desktop ]; then
    printf '%s' "$rendered" | jq -e '
      .commands.whiteboard.agent == "whiteboard"
      and .commands.whiteboard.subagent == false
      and (.commands.whiteboard.template | contains("$ARGUMENTS"))
      and (.plugins | index("./local-plugins/whiteboard") != null)
      and .mcp.servers.whiteboard.type == "local"
      and (has("default_agent") | not)' >/dev/null
    printf '%s\n' "$managed" | grep -q '^\.config/opencode/agents/whiteboard.md$'
    printf '%s\n' "$managed" | grep -q '^\.config/opencode/local-plugins/whiteboard/index.js$'
  else
    printf '%s' "$rendered" | jq -e '
      ((.commands // {}) | has("whiteboard") | not)
      and (.plugins | index("./local-plugins/whiteboard") == null)
      and (.mcp.servers | has("whiteboard") | not)' >/dev/null
    if printf '%s\n' "$managed" | grep -Eq '^\.config/opencode/(agents/whiteboard.md|local-plugins/whiteboard(/|$))'; then
      echo "$profile must not deploy Whiteboard mode" >&2
      exit 1
    fi
  fi
done
printf '%s\n' 'Whiteboard mode tests passed (session binding and desktop-only opt-in routing).'
