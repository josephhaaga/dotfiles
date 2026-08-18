#!/usr/bin/env bash

set -euo pipefail

repository="https://github.com/ohmyzsh/ohmyzsh.git"
revision="97e11051e2f8053b1d694788d1cb4b0dbb1e2365"
install_dir="$HOME/.oh-my-zsh"

if [ -e "$install_dir" ] && [ ! -d "$install_dir/.git" ]; then
  printf '%s\n' "$install_dir exists but is not an Oh My Zsh Git checkout" >&2
  exit 1
fi

if [ ! -d "$install_dir/.git" ]; then
  git init --quiet "$install_dir"
  git -C "$install_dir" remote add origin "$repository"
elif [ "$(git -C "$install_dir" remote get-url origin)" != "$repository" ]; then
  printf '%s\n' "$install_dir has an unexpected origin" >&2
  exit 1
fi

if ! git -C "$install_dir" diff --quiet || ! git -C "$install_dir" diff --cached --quiet; then
  printf '%s\n' "$install_dir has local changes; refusing to overwrite them" >&2
  exit 1
fi

git -C "$install_dir" fetch --quiet --depth 1 origin "$revision"
git -C "$install_dir" checkout --quiet --detach "$revision"
