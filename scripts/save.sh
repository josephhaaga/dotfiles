#!/bin/bash

COMMIT_MESSAGE="Autosave at $(date)"
repos=("$HOME/Documents/journal" "$HOME/Documents/dotfiles")

for repo in "${repos[@]}"; do
  TITLE=$(gum style --foreground 212 --bold "$repo")

  changes=$(git -C "$repo" status --porcelain)
  if [ -z "$changes" ]; then
    MESSAGE=$(gum style --italic --margin "0 1" "No changes to save. Skipping.")
  else
    MESSAGE=$(git -C "$repo" diff --stat HEAD | gum format -t code)
  fi

  gum join --vertical "$TITLE" "$MESSAGE"

  if [ -z "$changes" ]; then
    continue
  fi

  SAVE=$(git -C "$repo" add . >/dev/null 2>&1 && git -C "$repo" commit -m "${COMMIT_MESSAGE}" >/dev/null 2>&1 && git -C "$repo" push >/dev/null 2>&1)
  if [ "$SAVE" = 0 ]; then
    :
  else
    echo "Failed to save $repo" >&2
    continue
  fi
  echo

done
