#!/bin/bash

# Update repositories before starting a working session
repos=("~/Documents/journal" "~/Documents/dotfiles")

for repo in "${repos[@]}"; do
  echo "Updating $repo"
  if git -C "$repo" pull; then
    echo "$repo updated successfully."
  else
    echo "Failed to update $repo. Please check the error." >&2
    exit 1
  fi

done

