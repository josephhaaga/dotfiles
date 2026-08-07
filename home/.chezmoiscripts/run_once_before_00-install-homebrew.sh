#!/bin/bash
set -euo pipefail

if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Keep Homebrew available in future login shells without duplicate entries.
line='eval "$(/opt/homebrew/bin/brew shellenv)"'
file="$HOME/.zprofile"
touch "$file"
grep -qxF "$line" "$file" || printf '%s\n' "$line" >>"$file"
