#!/bin/bash

COMMIT_MESSAGE="Autosave at $(date)"
repos=("$HOME/Documents/journal" "$HOME/Documents/dotfiles")

for repo in "${repos[@]}"; do
  TITLE=$(gum style --foreground 212 --bold "$repo")

  changes=$(git -C "$repo" status --porcelain)
  if [ -z "$changes" ]; then
    MESSAGE=$(gum style --italic --margin "0 1" "No changes to save. Skipping.")
    continue
  fi

  MESSAGE=$(git -C "$repo" diff --stat HEAD | gum format -t code)

  gum join --vertical "$TITLE" "$MESSAGE"

  if git -C "$repo" add . && git -C "$repo" commit -m "${COMMIT_MESSAGE}" && git -C "$repo" push; then
    :
  else
    exit 1
  fi
  echo

done
