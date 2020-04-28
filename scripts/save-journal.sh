#!/bin/bash

COMMIT_MESSAGE=$1

$HOME/Documents/Utilities/evaluate_commit_message.sh "$COMMIT_MESSAGE"

MESSAGE_IS_SUFFICIENT=$?

if [ $MESSAGE_IS_SUFFICIENT -ne 0 ]; 
then
    echo "Commit message is insufficient."
    exit 1
else
    echo "Commit message is sufficient."
    echo "Saving Journal entries"
fi


cd $HOME/Documents/Journal
git add .
git commit -m "$1"
git push

exit
