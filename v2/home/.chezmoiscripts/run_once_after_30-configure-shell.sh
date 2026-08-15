#!/usr/bin/env bash

set -euo pipefail

# Keep $HOME literal so zsh evaluates it when loading ~/.zshenv.
# shellcheck disable=SC2016
line='export ZDOTDIR="$HOME/.config/zsh"'
touch "$HOME/.zshenv"
grep -qxF "$line" "$HOME/.zshenv" || printf '%s\n' "$line" >> "$HOME/.zshenv"

zsh_path="$(command -v zsh || true)"
if [ -n "$zsh_path" ] && [ "${SHELL:-}" != "$zsh_path" ]; then
  if [ "$(uname -s)" = Darwin ]; then
    grep -qxF "$zsh_path" /etc/shells || printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
  chsh -s "$zsh_path" || printf 'Run chsh -s %s to make zsh your login shell.\n' "$zsh_path" >&2
fi
