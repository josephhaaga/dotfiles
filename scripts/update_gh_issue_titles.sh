#!/bin/bash

# Get all issues
issues=$(gh issue list --json number,title -q '.[] | @base64')

for issue in $issues; do
  # Decode the issue details
  issue_info=$(echo "$issue" | base64 --decode)
  issue_number=$(echo "$issue_info" | jq '.number')
  title=$(echo "$issue_info" | jq -r '.title')
  
  # Check for ":" character and wrap the prefix in backticks if not already done
  if [[ "$title" == *":"* && "$title" != *\`* ]]; then
    new_title=$(echo "$title" | sed -E 's/^([^:]+):/`\1`:/')
    
    # Update the issue with the new title
    gh issue edit "$issue_number" --title "$new_title"
  fi
done
