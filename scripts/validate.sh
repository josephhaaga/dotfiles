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

# Zed configuration uses JSONC despite its .json extension.
while IFS= read -r -d '' file; do
  jq empty "$file"
done < <(find "$DOTFILES/configs" -path "$DOTFILES/configs/zed" -prune -o -name '*.json' -print0)

brew bundle list --file="$DOTFILES/configs/brew/Brewfile" >/dev/null
brew bundle list --file="$DOTFILES/configs/brew/Brewfile.work" >/dev/null
if [ "$check_installed" = true ]; then
  brew bundle check --file="$DOTFILES/configs/brew/Brewfile"
  brew bundle check --file="$DOTFILES/configs/brew/Brewfile.work"
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$DOTFILES"/scripts/*.sh "$DOTFILES"/scripts/lib/*.sh
fi

if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --source "$DOTFILES" --no-git
fi
