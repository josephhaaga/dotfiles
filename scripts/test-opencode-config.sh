#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/opencode-config.sh
source "$SCRIPT_DIR/lib/opencode-config.sh"

for config in \
  '{}' \
  '{"model":"openai/gpt-6.1-sol-fast"}' \
  '{"model":"github-copilot/model","default_agent":"build","agents":{"reviewer":{"mode":"subagent"}}}'; do
  if ! printf '%s' "$config" | validate_opencode_preferences; then
    echo "valid OpenCode preferences rejected: $config" >&2
    exit 1
  fi
done

for config in \
  '{"model":false}' \
  '{"model":"missing-provider"}' \
  '{"model":"openai/"}' \
  '{"model":"openai/model#high"}' \
  '{"model":"openai/model with spaces"}' \
  '{"default_agent":[]}' \
  '{"default_agent":""}' \
  '{"agents":[]}'; do
  if printf '%s' "$config" | validate_opencode_preferences 2>/dev/null; then
    echo "invalid OpenCode preferences accepted: $config" >&2
    exit 1
  fi
done

echo "OpenCode preference validation tests passed."
