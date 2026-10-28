#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home/.local/bin" "$fixture/home/.local/share/mise/shims"
export TEST_CALL_LOG="$fixture/calls"

cat > "$fixture/bin/launchctl" <<'SH'
#!/usr/bin/env bash
printf 'launchctl %s\n' "$*" >> "$TEST_CALL_LOG"
SH
cat > "$fixture/bin/systemctl" <<'SH'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$TEST_CALL_LOG"
SH
cat > "$fixture/home/.local/bin/agent-profiler" <<'SH'
#!/usr/bin/env bash
printf 'daemon %s\n' "$*" >> "$TEST_CALL_LOG"
SH
cat > "$fixture/home/.local/share/mise/shims/bun" <<'SH'
#!/usr/bin/env bash
printf 'bun %s\nhost=%s\nport=%s\nweb=%s\n' \
  "$*" "$AGENT_PROFILER_HOST" "$AGENT_PROFILER_PORT" "$AGENT_PROFILER_WEB_DIST" >> "$TEST_CALL_LOG"
SH
chmod +x "$fixture/bin/launchctl" "$fixture/bin/systemctl" \
  "$fixture/home/.local/bin/agent-profiler" "$fixture/home/.local/share/mise/shims/bun"

for profile in desktop enterprise server container; do
  rendered="$(chezmoi execute-template --source "$DOTFILES" --override-data "{\"profile\":\"$profile\"}" \
    < "$DOTFILES/home/.chezmoiscripts/run_onchange_after_55-configure-agent-profiler.sh.tmpl")"
  : > "$TEST_CALL_LOG"
  HOME="$fixture/home" PATH="$fixture/bin:$PATH" bash -c "$rendered"
  case "$profile" in
    desktop)
      grep -q '^launchctl bootstrap gui/' "$TEST_CALL_LOG"
      ! grep -qE '^(systemctl|daemon) ' "$TEST_CALL_LOG"
      ;;
    server)
      grep -q '^systemctl --user enable --now agent-profiler.service$' "$TEST_CALL_LOG"
      ! grep -qE '^(launchctl|daemon) ' "$TEST_CALL_LOG"
      ;;
    enterprise|container)
      grep -q '^daemon start$' "$TEST_CALL_LOG"
      ! grep -qE '^(launchctl|systemctl) ' "$TEST_CALL_LOG"
      ;;
  esac
done

: > "$TEST_CALL_LOG"
HOME="$fixture/home" bash "$DOTFILES/home/dot_local/bin/executable_agent-profiler-serve"
grep -q '^host=127.0.0.1$' "$TEST_CALL_LOG"
grep -q '^port=7070$' "$TEST_CALL_LOG"
grep -qF "bun run $fixture/home/.local/lib/node_modules/@josephhaaga/agent-profiler/dist/server/index.js" "$TEST_CALL_LOG"
printf '%s\n' 'Agent Profiler startup tests passed (all profiles, loopback-only foreground launcher).'
