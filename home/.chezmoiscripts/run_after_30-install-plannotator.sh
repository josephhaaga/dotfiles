#!/bin/bash
set -euo pipefail

# Update Plannotator during every chezmoi apply, including `chezmoi update` and
# `dotfiles update`. The OpenCode plugin remains declared in opencode.json.
curl -fsSL https://plannotator.ai/install.sh | bash
