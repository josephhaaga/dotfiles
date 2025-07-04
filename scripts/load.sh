#!/bin/bash

# Update repositories before starting a working session
repos=("$HOME/Documents/journal" "$HOME/Documents/dotfiles")

for repo in "${repos[@]}"; do
  TITLE=$(gum style --foreground 212 --bold "$repo")
  PULL=$(git -C "$repo" pull >/dev/null 2>&1)
  if [ "$PULL" = 0 ]; then
    MESSAGE=$(gum style --italic --margin "0 1" "Pulled latest changes")
  else
    echo "Failed to update $repo. Please check the error." >&2
    exit 1
  fi

done
