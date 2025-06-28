#!/bin/bash

# Update all aspects of the environment
set -e

# Pull latest changes for dotfiles and journal
~/Documents/dotfiles/scripts/load.sh

# Sync Homebrew dependencies
brew bundle --file=~/Documents/dotfiles/.config/brew/Brewfile

# Restart services (if required)
skhd --restart-service
yabai --restart-service

echo "Update complete! Your system is now up to date."