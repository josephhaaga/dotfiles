#!/bin/bash

tomorrow=$(date -v+1d +"%Y-%m-%d")
FILE="$HOME/Documents/Journal/journals/$tomorrow.md"

if [[ ! -f "$FILE" ]]; then
    echo "Creating tomorrow's journal entry: $tomorrow"
    touch $FILE
    echo "# $(date -v+1d)" >> $FILE
fi

vi $FILE
