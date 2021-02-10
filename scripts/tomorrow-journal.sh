#!/bin/bash

tomorrow=$(date -v+1d +"%Y-%m-%d")
FILE="$HOME/Documents/Journal/journals/$tomorrow.md"

if [[ ! -f "$FILE" ]]; then
    echo "Creating new journal entry for $today"
    touch $FILE
    echo "# $(date -v+1d)" >> $FILE
    echo "" >> $FILE
    echo "" >> $FILE
    echo "## How I spent my time today" >> $FILE
    echo "### Loved" >> $FILE
    echo "### Loathed" >> $FILE
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
