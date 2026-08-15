#!/usr/bin/env bash

set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

profile="${DOTFILES_PROFILE:-}"
if [ -z "$profile" ]; then
  if [ "$(uname -s)" = Darwin ]; then
    profile=desktop
  elif [ -f /.dockerenv ] || [ -n "${container:-}" ]; then
    profile=container
  else
    profile=server
  fi
fi

case "$profile" in
  desktop|server|container) ;;
  *)
    printf 'Invalid DOTFILES_PROFILE: %s\n' "$profile" >&2
    exit 2
    ;;
esac

required=(chezmoi mise zsh nvim herdr uv node bun go rg fd starship gh opencode2 kubectl neofetch tree-sitter)
status=0

for command_name in "${required[@]}"; do
  if command -v "$command_name" >/dev/null 2>&1; then
    printf '[ok] %s\n' "$command_name"
  else
    printf '[missing] %s\n' "$command_name" >&2
    status=1
  fi
done

herdr --version >/dev/null
opencode2 --version >/dev/null
kubectl version --client >/dev/null

zsh -lic true
if command -v nvim >/dev/null 2>&1; then
  nvim --headless '+Lazy! sync' '+lua vim.wait(30000)' \
    '+lua print("Neovim configuration loaded")' +qa
fi

if [ "$profile" != container ]; then
  command -v docker >/dev/null 2>&1 || status=1
fi

if [ "$profile" = server ]; then
  systemctl is-active --quiet docker.service || status=1
  systemctl is-active --quiet crond.service || status=1
fi

exit "$status"
