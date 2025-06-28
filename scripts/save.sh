#!/bin/bash

COMMIT_MESSAGE="Autosave at $(date)"
repos=("$HOME/Documents/journal" "$HOME/Documents/dotfiles")

for repo in "${repos[@]}"; do
  echo "Saving changes in $repo"
  if git -C "$repo" diff --quiet && git -C "$repo" diff --staged --quiet && git -C "$repo" rev-parse --verify HEAD; then
    echo "No changes to save in $repo. Skipping."
    continue
  fi

  echo "$COMMIT_MESSAGE"
  if git -C "$repo" add . && git -C "$repo" commit -m "${COMMIT_MESSAGE}" && git -C "$repo" push; then
    echo "$repo changes saved and pushed successfully."
  else
    echo "Failed to save changes in $repo. Please check the error." >&2
    exit 1
  fi

done

