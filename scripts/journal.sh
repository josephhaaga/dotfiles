#!/bin/bash

today=$(date +"%Y-%m-%d")
FILE="$HOME/Documents/Journal/journals/$today.md"

if [[ ! -f "$FILE" ]]; then
    echo "Creating new journal entry for $today"
    touch $FILE
    echo "# $(date)" >> $FILE
    echo "" >> $FILE
#   echo "" >> $FILE
#   echo "## Self Care" >> $FILE
#   echo "Physical: " >> $FILE
#   echo "Psychological" >> $FILE
#   echo "Social: " >> $FILE
#   echo "Spiritual: " >> $FILE
#   echo "Professional: " >> $FILE
#   echo "" >> $FILE
fi

vi $FILE
