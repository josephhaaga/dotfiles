#!/bin/bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: slackmd <slack-thread-url> [--download-dir DIR] [--no-download]" >&2
    exit 1
fi

URL="$1"
shift
SCRIPT_DIR="$(dirname "$0")"

gh slackdump -u "$URL" | python3 "$SCRIPT_DIR/format_slackdump_as_md.py" "$@"
