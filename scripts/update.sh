#!/bin/bash

# Update all aspects of the environment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$SCRIPT_DIR/.." && pwd)"

# Pull latest changes for dotfiles and journal
"$DOTFILES/scripts/load.sh"

# Sync Homebrew dependencies
brew bundle --file="$DOTFILES/configs/brew/Brewfile"

# Restart services (if required)
"$DOTFILES/scripts/macos-defaults.sh"
"$DOTFILES/scripts/window-manager.sh" restart

# Set ZDOTDIR
touch "$HOME/.zshenv"
grep -qxF 'export ZDOTDIR="$HOME/.config/zsh"' "$HOME/.zshenv" || \
  printf '%s\n' 'export ZDOTDIR="$HOME/.config/zsh"' >> "$HOME/.zshenv"

echo "Update complete! Your system is now up to date."
