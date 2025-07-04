#!/bin/bash

# Update repositories before starting a working session
repos=("$HOME/Documents/journal" "$HOME/Documents/dotfiles")

exit_code=0

for repo in "${repos[@]}"; do
  TITLE=$(gum style --foreground 212 --bold "$repo")

  git -C "$repo" fetch origin >/dev/null 2>&1
  LOCAL=$(git -C "$repo" rev-parse @)
  REMOTE=$(git -C "$repo" rev-parse @{u})
  BASE=$(git -C "$repo" merge-base @ @{u})

  if [ "$LOCAL" = "$REMOTE" ]; then
    # Up to date
    MESSAGE=$(gum style --italic --margin "0 1" "No updates to pull.")
  elif [ "$LOCAL" = "$BASE" ]; then
    # Behind
    PULL=$(git -C "$repo" pull >/dev/null 2>&1)
    if [ "$PULL" = 0 ]; then
      MESSAGE=$(gum style --italic --margin "0 1" "Pulled latest changes")
    else
      echo "Failed to update $repo. Please check the error." >&2
      exit_code = 1
    fi
  elif [ "$REMOTE" = "$BASE" ]; then
    # Ahead
    MESSAGE=$(gum style --italic --margin "0 1" "No updates to pull.")
  else
    # Diverged
    MESSAGE=$(gum style --italic --margin "0 1" "Diverged from remote!")
    exit_code = 1
  fi

  gum join --vertical "$TITLE" "$MESSAGE"

done

exit $exit_code
