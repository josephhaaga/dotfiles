#!/bin/bash

# Install dependencies and set up environment
set -e

# Ensure Homebrew is installed
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Source Brew environment
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install Brew dependencies
brew bundle --file=~/Documents/dotfiles/.config/brew/Brewfile

# Symlink configuration files
ln -sf ~/Documents/dotfiles/.config ~

# Set up oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Start essential services
yabai --start-service
skhd --start-service

# Set up Neovim
brew reinstall neovim
vim -c ':PlugInstall' --headless +qall

# Final message
echo "Installation complete! Please restart your terminal for changes to take effect."