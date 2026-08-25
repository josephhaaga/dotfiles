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
