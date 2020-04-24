#!/bin/bash

# Eventually we can add conventionalcommits.com rules
COMMIT_MESSAGE=$1

# More than one word
space=" "
if ! [[ $COMMIT_MESSAGE = *" "* ]]
then
    echo "Commit message needs to be more than one word!"
    exit 1
fi

exit 0
