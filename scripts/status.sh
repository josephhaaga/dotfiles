#!/bin/bash

# Check whether the local environment matches expected dotfiles configuration.
# Exits non-zero if any check fails.

PASS=0
FAIL=1
status=0

check() {
  local label="$1"
  local result="$2"  # 0 = pass, 1 = fail
  local detail="${3:-}"
  if [ "$result" -eq 0 ]; then
    echo "  [ok]  $label"
  else
    echo "  [!!]  $label${detail:+: $detail}"
    status=1
  fi
}

echo "=== dotfiles status ==="
echo ""

# --- Symlinks ---
echo "Symlinks"
[ -L "$HOME/configs" ] && [ "$(readlink "$HOME/configs")" = "$HOME/Documents/dotfiles/configs" ]
check "~/configs -> dotfiles/configs" $?

[ -L "$HOME/.clerkrc" ]
check "~/.clerkrc symlink exists" $?

# --- git config ---
echo ""
echo "git config"
GITCONFIG="$HOME/.gitconfig"
INCLUDE_LINE="path = ~/configs/git/.gitconfig"

grep -qF "$INCLUDE_LINE" "$GITCONFIG" 2>/dev/null
check "~/.gitconfig includes configs/git/.gitconfig" $?

git config --get alias.glo >/dev/null 2>&1
check "git alias 'glo' is resolvable" $?

# --- Shell ---
echo ""
echo "Shell"
grep -q 'ZDOTDIR' "$HOME/.zshenv" 2>/dev/null
check "ZDOTDIR set in ~/.zshenv" $?

# --- Tools ---
echo ""
echo "Tools"
command -v brew >/dev/null 2>&1
check "brew installed" $?

command -v uv >/dev/null 2>&1
check "uv installed" $?

command -v gh >/dev/null 2>&1
check "gh installed" $?

echo ""
if [ "$status" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks failed."
fi

exit $status
