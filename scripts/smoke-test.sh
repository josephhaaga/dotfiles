#!/usr/bin/env bash

set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$SCRIPT_DIR/.." && pwd)"

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
  desktop|enterprise|server|container) ;;
  *)
    printf 'Invalid DOTFILES_PROFILE: %s\n' "$profile" >&2
    exit 2
    ;;
esac

required=(chezmoi mise zsh nvim herdr uv node bun go rg fd starship stylua gh opencode kubectl kubelogin neofetch tree-sitter)

if [ "$profile" = server ]; then
  required+=(caddy)
fi

# Derive profile-specific npm commands from the same package inventory used by
# chezmoi, so smoke coverage follows packages.yaml without a second list.
package_data="$DOTFILES/home/.chezmoidata/packages.yaml"
if [ -f "$package_data" ]; then
  npm_groups=(npm)
  [ "$profile" = server ] && npm_groups+=(npm_server)
  for npm_group in "${npm_groups[@]}"; do
    while IFS= read -r package; do
      case "$package" in
        @opencode/cli) command_name=opencode ;;
        @openchamber/web) command_name=openchamber ;;
        @plannotator/opencode) continue ;;
        tree-sitter-cli) command_name=tree-sitter ;;
        *) command_name="${package##*/}" ;;
      esac
      required+=("$command_name")
    done < <(sed -n "/^  ${npm_group}:/,/^  [[:alnum:]_][[:alnum:]_]*:/s/^    \"\{0,1\}\([^\"]*\)\"\{0,1\}: .*/\1/p" "$package_data")
  done
fi
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
opencode --version >/dev/null
kubectl version --client >/dev/null
kubelogin --version >/dev/null

zsh -lic 'alias gst >/dev/null'
if command -v nvim >/dev/null 2>&1; then
  nvim --headless '+Lazy! restore' '+lua vim.wait(30000)' \
    '+lua print("Neovim configuration loaded")' +qa
fi

if [ "$profile" = desktop ] || [ "$profile" = server ]; then
  command -v docker >/dev/null 2>&1 || status=1
fi

if [ "$profile" = server ]; then
  systemctl is-active --quiet caddy.service || status=1
  systemctl --user is-active --quiet opencode.service || status=1
  systemctl --user is-active --quiet openchamber.service || status=1
  systemctl is-active --quiet docker.service || status=1
  systemctl is-active --quiet crond.service || status=1
  curl --fail --silent --output /dev/null http://127.0.0.1:3000/ || status=1
fi

exit "$status"
