#!/bin/bash

# Update all aspects of the environment
set -e

# Pull latest changes for dotfiles and journal
~/Documents/dotfiles/scripts/load.sh

# Sync Homebrew dependencies
brew bundle --file=~/.config/brew/Brewfile

# Restart services (if required)
skhd --restart-service
yabai --restart-service

# Set ZDOTDIR
echo 'export ZDOTDIR="$HOME/.config/zsh"' >> ~/.zshenv

echo "Update complete! Your system is now up to date."
