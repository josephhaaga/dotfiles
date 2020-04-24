#!/bin/bash

COMMIT_MESSAGE=$1

$HOME/Documents/Utilities/evaluate_commit_message.sh "$COMMIT_MESSAGE"

MESSAGE_IS_SUFFICIENT=$?

if [ $MESSAGE_IS_SUFFICIENT -ne 0 ]; 
then
    echo "Commit message is insufficient."
else
    echo "Commit message is sufficient."
    echo "Saving files in $PWD"
fi



git add .
git commit -m "$1"
git push

exit
