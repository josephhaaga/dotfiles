#!/bin/bash

today=$(date +"%Y-%m-%d")
FILE="$HOME/Documents/Journal/$today.md"

if [[ ! -f "$FILE" ]]; then
    echo "Creating new journal entry for $today"
    touch $FILE
    echo "# $(date)" >> file
fi

vi $FILE
