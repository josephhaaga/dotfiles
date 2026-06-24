#!/bin/bash

# Install dependencies and set up environment
set -euxo pipefail

# Ensure Homebrew is installed
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Source Brew environment
(
  echo
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
) >>"$HOME/.zprofile"
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install Brew dependencies
brew bundle --file=$HOME/Documents/dotfiles/configs/brew/Brewfile

# Symlink configuration files
# Set ZDOTDIR
echo 'export ZDOTDIR="$HOME/.config/zsh"' >>$HOME/.zshenv

ln -sf $HOME/Documents/dotfiles/configs $HOME
ln -sf $HOME/Documents/dotfiles/.clerkrc $HOME/.clerkrc

# Install Python CLI tools
uv tool install --force git+https://github.com/josephhaaga/clerk.git
uv tool install --force pre-commit

# Set up oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install gh extensions
gh extension install wham/gh-slackdump 2>/dev/null || true

# Start essential services
"$HOME/Documents/dotfiles/scripts/window-manager.sh" start

# Set up Tailscale for remote OpenCode access
echo ""
echo "=== Tailscale setup ==="
echo "Tailscale was installed via Homebrew. Next steps:"
echo "  1. Create a free account at https://login.tailscale.com/start (if you don't have one)"
echo "  2. Open the Tailscale menu bar app and sign in"
echo "     (or run: /Applications/Tailscale.app/Contents/MacOS/Tailscale up)"
echo "  3. Enable MagicDNS in the admin console: https://login.tailscale.com/admin/dns"
echo "     (tick 'Enable MagicDNS' — free on all plans)"
echo "  4. Store your OpenCode server password in Keychain (one-time):"
echo "     security add-generic-password -a \"\$USER\" -s opencode-server -w 'your-password'"
echo "  5. To serve OpenCode to your phone: ~/Documents/dotfiles/scripts/serve-opencode.sh"
echo "     Then on your phone (connected to Tailscale), open:"
echo "       http://<your-mac-magicdns-name>:4096"
echo "     For the mobile-friendly UI, also run: bunx openportal  (port 3000)"
echo ""

# Final message
echo "Installation complete! Please restart your terminal for changes to take effect."
