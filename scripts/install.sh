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

# Set up oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install gh extensions
gh extension install wham/gh-slackdump 2>/dev/null || true

# Start essential services
yabai --start-service
skhd --start-service

# Set up whisp (local voice dictation with LLM rewrite)
echo ""
echo "=== whisp setup ==="
WHISP_DIR="$HOME/.config/whisp"
if [ -d "$WHISP_DIR" ]; then
  # Make the pipeline scripts executable.
  chmod +x "$WHISP_DIR"/bin/*.sh 2>/dev/null || true

  # Symlink the Übersicht widget (its widgets dir is outside ~/.config).
  UB_WIDGETS="$HOME/Library/Application Support/Übersicht/widgets"
  mkdir -p "$UB_WIDGETS"
  ln -sfn "$WHISP_DIR/ubersicht/whisp.widget" "$UB_WIDGETS/whisp.widget"
  # Launch / refresh Übersicht so the overlay loads.
  open -a "Übersicht" 2>/dev/null || \
    echo "  (could not auto-launch Übersicht; open it manually once installed)"

  # Download the default Whisper GGML model if missing (guarded; ~1.6 GB).
  WHISP_MODEL="ggml-large-v3-turbo.bin"
  WHISP_MODEL_PATH="$WHISP_DIR/models/$WHISP_MODEL"
  if [ ! -f "$WHISP_MODEL_PATH" ]; then
    echo "  Downloading Whisper model $WHISP_MODEL (~1.6 GB)…"
    curl -fL --retry 3 -o "$WHISP_MODEL_PATH" \
      "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$WHISP_MODEL" \
      || echo "  (model download failed; re-run or fetch $WHISP_MODEL manually into $WHISP_DIR/models/)"
  fi

  # Pull the default local LLM for rewrite (guarded).
  if command -v ollama >/dev/null 2>&1; then
    echo "  Pulling local LLM (llama3.1:8b) for rewrite…"
    (ollama pull llama3.1:8b || echo "  (ollama pull failed; run 'ollama pull llama3.1:8b' later)")
  fi

  echo "  Permissions needed (one-time):"
  echo "    - Microphone: System Settings > Privacy & Security > Microphone > enable skhd"
  echo "    - Accessibility: enable skhd (already required for window mgmt)"
  echo "    - Screen Recording: System Settings > Privacy & Security > Screen Recording > enable Übersicht"
  echo "  Reload skhd to pick up the whisp chord:"
  skhd --reload 2>/dev/null || skhd --restart-service 2>/dev/null || true
  echo "  Use it: press Control+V, then a letter (r/c/e/w). Press again (or Control+Shift+V) to finish."
fi

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
