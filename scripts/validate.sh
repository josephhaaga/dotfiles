#!/usr/bin/env bash

# Validate tracked configuration without changing machine state.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$SCRIPT_DIR/.." && pwd)"
check_installed=false

if [ "${1:-}" = "--check-installed" ]; then
  check_installed=true
elif [ -n "${1:-}" ]; then
  echo "Usage: $0 [--check-installed]" >&2
  exit 2
fi

bash -n "$DOTFILES"/scripts/*.sh "$DOTFILES"/scripts/lib/*.sh

while IFS= read -r -d '' file; do
  jq empty "$file"
done < <(find "$DOTFILES/configs" -name '*.json' -print0)

# Validate the chezmoi-rendered Brewfile if it's already been applied to this
# machine; packages.yaml itself has no direct syntax check beyond being valid
# YAML, which `chezmoi execute-template` would catch on the next apply.
if [ -f "$HOME/.config/brew/Brewfile" ]; then
  brew bundle list --file="$HOME/.config/brew/Brewfile" >/dev/null
  if [ "$check_installed" = true ]; then
    brew bundle check --file="$HOME/.config/brew/Brewfile"
  fi
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$DOTFILES"/scripts/*.sh "$DOTFILES"/scripts/lib/*.sh
fi

if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --source "$DOTFILES" --no-git
fi

# Validate the active cross-platform source without applying it to $HOME.
V2_SOURCE="$DOTFILES/v2/home"
if [ -d "$V2_SOURCE" ]; then
  bash -n "$DOTFILES/setup"

  while IFS= read -r -d '' file; do
    if head -n 1 "$file" | grep -qE '^#!.*(ba)?sh'; then
      bash -n "$file"
    fi
  done < <(find "$V2_SOURCE" -type f \( -name '*.sh' -o -name 'executable_*' \) ! -name '*.tmpl' -print0)

  zsh -n "$V2_SOURCE/dot_config/zsh/dot_zshrc"

  jq empty \
    "$V2_SOURCE/dot_config/nvim/lazy-lock.json" \
    "$V2_SOURCE/dot_config/nvim/lazyvim.json" \
    "$V2_SOURCE/dot_config/opencode/cli.json"

  python3 -c 'import pathlib, sys; compile(pathlib.Path(sys.argv[1]).read_bytes(), sys.argv[1], "exec")' \
    "$V2_SOURCE/dot_local/lib/dotfiles/format_slackdump_as_md.py"

  if DOTFILES_PROFILE=invalid chezmoi execute-template --source "$V2_SOURCE" \
    < "$V2_SOURCE/.chezmoi.toml.tmpl" >/dev/null 2>&1; then
    echo "v2 accepted an invalid profile" >&2
    exit 1
  fi

  # Without an explicit sourceDir chezmoi defaults to ~/.local/share/chezmoi,
  # which this repository never creates, so bare chezmoi commands fail.
  if ! DOTFILES_PROFILE=desktop chezmoi execute-template --source "$V2_SOURCE" \
    < "$V2_SOURCE/.chezmoi.toml.tmpl" | grep -q '^sourceDir = '; then
    echo "generated chezmoi.toml does not pin sourceDir" >&2
    exit 1
  fi

  # macOS always detects as "desktop", so a re-run of `chezmoi init` on an
  # enterprise machine must not silently revert the profile and install the full
  # desktop cask list. The recorded profile has to outrank OS detection.
  profile_home="$(mktemp -d)"
  mkdir -p "$profile_home/.config/chezmoi"
  printf 'sourceDir = %s\n\n[data]\n    profile = "enterprise"\n    managedSecrets = false\n' \
    "\"$V2_SOURCE\"" > "$profile_home/.config/chezmoi/chezmoi.toml"
  recorded_profile="$(HOME="$profile_home" chezmoi execute-template \
    --source "$V2_SOURCE" < "$V2_SOURCE/.chezmoi.toml.tmpl" |
    sed -n 's/^ *profile = "\(.*\)"$/\1/p')"
  rm -rf "$profile_home"
  if [ "$recorded_profile" != "enterprise" ]; then
    echo "re-init does not preserve the recorded profile (got ${recorded_profile:-empty})" >&2
    exit 1
  fi

  for profile in desktop enterprise server container; do
    data="{\"profile\":\"$profile\"}"

    chezmoi execute-template --source "$V2_SOURCE" --override-data "$data" \
      < "$V2_SOURCE/dot_config/opencode/opencode.json.tmpl" | jq empty

    if command -v uv >/dev/null 2>&1; then
      chezmoi execute-template --source "$V2_SOURCE" --override-data "$data" \
        < "$V2_SOURCE/dot_config/mise/config.toml.tmpl" |
        uv run --quiet --no-project --with tomli python -c \
          'import sys, tomli; tomli.loads(sys.stdin.read())'
    else
      chezmoi execute-template --source "$V2_SOURCE" --override-data "$data" \
        < "$V2_SOURCE/dot_config/mise/config.toml.tmpl" |
        python3 -c 'import sys, tomllib; tomllib.loads(sys.stdin.read())'
    fi

    while IFS= read -r -d '' template; do
      chezmoi execute-template --source "$V2_SOURCE" --override-data "$data" \
        < "$template" | bash -n
    done < <(find "$V2_SOURCE/.chezmoiscripts" -type f -name '*.sh.tmpl' -print0)
  done

  enterprise_managed="$(chezmoi managed --source "$V2_SOURCE" \
    --override-data '{"profile":"enterprise"}')"
  enterprise_excluded='^(\.config/caddy(/|$)|\.config/opencode/opencode-vm\.env$|\.local/bin/slackmd$|Documents/obsidian-vault(/|$)|Library(/|$))'
  if printf '%s\n' "$enterprise_managed" | grep -Eq "$enterprise_excluded"; then
    echo "enterprise profile manages a desktop, server, or local-vault path" >&2
    printf '%s\n' "$enterprise_managed" | grep -E "$enterprise_excluded" >&2
    exit 1
  fi

  # The enterprise network blocks unreviewed outbound endpoints and only
  # GitHub Copilot is an approved model provider, so opencode ships an explicit
  # provider allowlist and only individually reviewed MCP servers. Servers are
  # opt-in per name rather than inherited from the other profiles; adding one
  # here is the record that its outbound behaviour was reviewed.
  enterprise_mcp_allowlist='["playwright"]'
  enterprise_opencode="$(chezmoi execute-template --source "$V2_SOURCE" \
    --override-data '{"profile":"enterprise"}' \
    < "$V2_SOURCE/dot_config/opencode/opencode.json.tmpl")"
  if ! printf '%s' "$enterprise_opencode" |
    jq -e --argjson allowed "$enterprise_mcp_allowlist" \
      '((.mcp.servers // {}) | keys) - $allowed | length == 0' >/dev/null; then
    echo "enterprise opencode config declares unreviewed MCP servers" >&2
    printf '%s' "$enterprise_opencode" |
      jq -r --argjson allowed "$enterprise_mcp_allowlist" \
        '((.mcp.servers // {}) | keys) - $allowed | .[]' >&2
    exit 1
  fi
  if ! printf '%s' "$enterprise_opencode" |
    jq -e '.enabled_providers == ["github-copilot"]' >/dev/null; then
    echo "enterprise opencode config must allow only the github-copilot provider" >&2
    exit 1
  fi

  # npm --prefix relocates the global npmrc, dropping a private registry and
  # falling back to registry.npmjs.org, which fails behind a TLS-inspecting
  # proxy. Every profile must pass the resolved registry explicitly.
  # shellcheck disable=SC2016 # matching the literal shell source, not expanding it
  registry_flag='--registry "$npm_registry"'
  for profile in desktop enterprise server container; do
    if ! chezmoi execute-template --source "$V2_SOURCE" \
      --override-data "{\"profile\":\"$profile\"}" \
      < "$V2_SOURCE/.chezmoiscripts/run_onchange_after_50-install-agent-tools.sh.tmpl" |
      grep -qF -- "$registry_flag"; then
      echo "agent tool install for $profile does not pin the npm registry" >&2
      exit 1
    fi
  done

  for profile in desktop enterprise; do
    chezmoi execute-template --source "$V2_SOURCE" \
      --override-data "{\"profile\":\"$profile\"}" \
      < "$V2_SOURCE/dot_config/brew/Brewfile.tmpl" | ruby -c >/dev/null
  done

  enterprise_casks="$(chezmoi execute-template --source "$V2_SOURCE" \
    --override-data '{"profile":"enterprise"}' \
    < "$V2_SOURCE/dot_config/brew/Brewfile.tmpl" |
    sed -n 's/^cask "\([^"]*\)"$/\1/p' | sort)"
  expected_enterprise_casks="$(printf '%s\n' \
    font-hack-nerd-font font-jetbrains-mono ghostty | sort)"
  if [ "$enterprise_casks" != "$expected_enterprise_casks" ]; then
    echo "enterprise Brewfile casks differ from the approved allowlist" >&2
    printf '%s\n' "$enterprise_casks" >&2
    exit 1
  fi

  if grep -Rqi --exclude='*.spl' 'tmux' "$V2_SOURCE"; then
    echo "v2 must not contain tmux configuration or dependencies" >&2
    exit 1
  fi

  if grep -Rq --exclude='*.spl' -E '/Users/[^/]+|Documents/dotfiles' "$V2_SOURCE"; then
    echo "v2 contains a hard-coded home or repository path" >&2
    exit 1
  fi
fi
