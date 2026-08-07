#!/bin/bash
set -euo pipefail

line='export ZDOTDIR="$HOME/.config/zsh"'
file="$HOME/.zshenv"
touch "$file"
grep -qxF "$line" "$file" || printf '%s\n' "$line" >>"$file"
