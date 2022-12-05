#!/bin/bash

COMMIT_MESSAGE="Autosave at $(date)"

echo $COMMIT_MESSAGE

git -C ~/Documents/Journal add .
git -C ~/Documents/Journal commit -m "${COMMIT_MESSAGE}"
git -C ~/Documents/Journal push

git -C ~/Documents/dotfiles add .
git -C ~/Documents/dotfiles commit -m "${COMMIT_MESSAGE}"
git -C ~/Documents/dotfiles push


# 1. Check if there are any changes (unstaged, staged, committed etc.) that don't exist in the remote
# 2. If so, autogenerate a commit message (e.g. "Autosave at {datetime}")
# 3. Stage, commit, and push
