#!/usr/bin/env bash

# Report Homebrew and App Store state that is not declared in this repository.
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# packages.yaml (rendered to ~/.config/brew/Brewfile by chezmoi) is the single
# source of truth for both shared and work-only packages; the `work` template
# var determines whether work_casks are included on this machine.
brew bundle list --file="$HOME/.config/brew/Brewfile" --formula --cask |
  sort -u > "$tmpdir/declared"

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
