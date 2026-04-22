#!/bin/bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: slackmd <slack-thread-url>" >&2
    exit 1
fi

URL="$1"
SCRIPT_DIR="$(dirname "$0")"

gh slackdump -u "$URL" | python3 "$SCRIPT_DIR/format_slackdump_as_md.py"
