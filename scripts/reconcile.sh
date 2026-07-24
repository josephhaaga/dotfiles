#!/usr/bin/env bash

# Report Homebrew and App Store state that is not declared in this repository.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$SCRIPT_DIR/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

brew bundle list --file="$DOTFILES/configs/brew/Brewfile" --formula --cask |
  sort -u > "$tmpdir/declared"
brew bundle list --file="$DOTFILES/configs/brew/Brewfile.work" --cask |
  sort -u >> "$tmpdir/declared"
sort -u -o "$tmpdir/declared" "$tmpdir/declared"

{ brew list --formula; brew list --cask; } | sort -u > "$tmpdir/installed"

echo "== Homebrew installed but undeclared =="
comm -23 "$tmpdir/installed" "$tmpdir/declared" || true
echo "== Declared but not installed =="
comm -13 "$tmpdir/installed" "$tmpdir/declared" || true

echo "== Mac App Store applications =="
mas list || true

echo "== Applications to review =="
shopt -s nullglob
for app in /Applications/*.app "$HOME"/Applications/*.app; do
  basename "$app"
done | sort -fu
