#!/bin/bash

today=$(date +"%Y-%m-%d")
FILE="$HOME/Documents/Journal/journals/$today.md"

if [[ ! -f "$FILE" ]]; then
    echo "Creating new journal entry for $today"
    touch $FILE
    echo "# $(date)" >> $FILE
    echo "" >> $FILE
    echo "What are individuals on your team working on?" >> $FILE
    echo "Who on your team is blocked, and what action is being taken to correct?" >> $FILE
    echo "What tickets are exceeding the estimate, and what action (if any is needed) is being taken to correct?" >> $FILE
    echo "Who has not committed any code for more than two days, and what is the reason?" >> $FILE
    echo "" >> $FILE
fi

vi $FILE
