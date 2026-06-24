#!/bin/bash

# Update all aspects of the environment
set -e

# Pull latest changes for dotfiles and journal
$HOME/Documents/dotfiles/scripts/load.sh

# Sync Homebrew dependencies
brew bundle --file=$HOME/.config/brew/Brewfile

# Restart services (if required)
"$HOME/Documents/dotfiles/scripts/window-manager.sh" restart

# Set ZDOTDIR
echo 'export ZDOTDIR="$HOME/.config/zsh"' >>$HOME/.zshenv

echo "Update complete! Your system is now up to date."
