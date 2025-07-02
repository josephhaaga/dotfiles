#!/bin/bash

COMMIT_MESSAGE="Autosave at $(date)"
repos=("$HOME/Documents/journal" "$HOME/Documents/dotfiles")

for repo in "${repos[@]}"; do
  # gum style --foreground 212 "$repo"
  gum style --bold "$repo"

  changes=$(git -C "$repo" status --porcelain)
  if [ -z "$changes" ]; then
    gum style --italic --margin "0 1" "No changes to save. Skipping."
    continue
  fi

  diffstat=$(git -C "$repo" diff --stat HEAD)
  echo "$diffstat" | gum format -t code

  if git -C "$repo" add . && git -C "$repo" commit -m "${COMMIT_MESSAGE}" && git -C "$repo" push; then
    :
  else
    exit 1
  fi
  echo

done
