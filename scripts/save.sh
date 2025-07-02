#!/bin/bash

COMMIT_MESSAGE="Autosave at $(date)"
repos=("$HOME/Documents/journal" "$HOME/Documents/dotfiles")

for repo in "${repos[@]}"; do
  echo "{{ Bold $repo }}" | gum format -t template

  changes=$(git -C "$repo" status --porcelain)
  if [ -z "$changes" ]; then
    echo "No changes to save. Skipping."
    continue
  fi

  diffstat=$(git -C "$repo" diff --stat HEAD)
  echo "$diffstat"

  if git -C "$repo" add . && git -C "$repo" commit -m "${COMMIT_MESSAGE}" && git -C "$repo" push; then
    :
  else
    exit 1
  fi
  echo

done
