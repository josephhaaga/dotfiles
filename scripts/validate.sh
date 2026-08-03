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

if command -v chezmoi >/dev/null 2>&1; then
  chezmoi execute-template < "$DOTFILES/home/dot_config/brew/Brewfile.tmpl" >/dev/null
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$DOTFILES"/scripts/*.sh "$DOTFILES"/scripts/lib/*.sh
fi

if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --source "$DOTFILES" --no-git
fi
