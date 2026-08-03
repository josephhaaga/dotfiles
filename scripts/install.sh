#!/bin/bash

# Install dependencies and set up environment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$SCRIPT_DIR/.." && pwd)"
install_work=false

if [ "${1:-}" = "--work" ]; then
  install_work=true
elif [ -n "${1:-}" ]; then
  echo "Usage: $0 [--work]" >&2
  exit 2
fi

append_once() {
  local line="$1" file="$2"
  touch "$file"
  grep -qxF "$line" "$file" || printf '%s\n' "$line" >> "$file"
}

# Ensure Homebrew is installed
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Keep Homebrew available in future login shells without duplicate entries.
append_once 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$HOME/.zprofile"
eval "$(brew shellenv)"

# Install Brew dependencies
brew bundle --file="$DOTFILES/configs/brew/Brewfile"
if [ "$install_work" = true ]; then
  brew bundle --file="$DOTFILES/configs/brew/Brewfile.work"
fi

# Install the Plannotator CLI and OpenCode review commands. The OpenCode plugin
# itself is declared in configs/opencode/opencode.json.
curl -fsSL https://plannotator.ai/install.sh | bash

# Symlink configuration files
link_config() {
  local source="$1" destination="$2"

  mkdir -p "$(dirname "$destination")"
  if [ -e "$destination" ] && [ ! -L "$destination" ]; then
    mv "$destination" "$destination.pre-dotfiles"
  fi
  ln -sfn "$source" "$destination"
}

# Set ZDOTDIR
append_once 'export ZDOTDIR="$HOME/.config/zsh"' "$HOME/.zshenv"

link_config "$DOTFILES/.clerkrc" "$HOME/.clerkrc"

# Link only declarative configuration. gh, gcloud, and opencode keep local
# state under ~/.config and must not be replaced by a repository symlink.
for config in brew fish ghostty httpie neofetch nvim tealdeer tmux uv yabai; do
  link_config "$DOTFILES/configs/$config" "$HOME/.config/$config"
done
link_config "$DOTFILES/configs/zsh/.zshrc" "$HOME/.config/zsh/.zshrc"
link_config "$DOTFILES/configs/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
link_config "$DOTFILES/configs/starship.toml" "$HOME/.config/starship.toml"
link_config "$DOTFILES/configs/.bigqueryrc" "$HOME/.config/.bigqueryrc"

# OpenCode keeps dependencies and credentials locally, but its declarative
# configuration, commands, skills, and plugins are tracked in this repository.
if [ -f "$HOME/.config/opencode/opencode.jsonc" ] && \
   [ ! -L "$HOME/.config/opencode/opencode.jsonc" ]; then
  mv "$HOME/.config/opencode/opencode.jsonc" \
    "$HOME/.config/opencode/opencode.jsonc.pre-dotfiles"
fi
for config in opencode.json opencode.personal.json opencode.work.json; do
  link_config "$DOTFILES/configs/opencode/$config" "$HOME/.config/opencode/$config"
done
for directory in commands skills hub local-plugins; do
  link_config "$DOTFILES/configs/opencode/$directory" "$HOME/.config/opencode/$directory"
done

# These tools use fixed paths outside the XDG configuration directory.
link_config "$DOTFILES/configs/skhd/skhdrc" "$HOME/.skhdrc"
link_config "$DOTFILES/configs/tmux/tmux.conf" "$HOME/.tmux.conf"

# Apply versioned macOS preferences.
"$DOTFILES/scripts/macos-defaults.sh"

# Wire dotfiles git config into ~/.gitconfig via [include]
GITCONFIG="$HOME/.gitconfig"
INCLUDE_LINE="path = $DOTFILES/configs/git/.gitconfig"
if ! grep -qF "$INCLUDE_LINE" "$GITCONFIG" 2>/dev/null; then
  printf '\n[include]\n\t%s\n' "$INCLUDE_LINE" >> "$GITCONFIG"
  echo "Added [include] for configs/git/.gitconfig to ~/.gitconfig"
fi

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
"$DOTFILES/scripts/window-manager.sh" start

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
