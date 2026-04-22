#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: slackmd <slack-thread-url> [-o DIR]" >&2
    echo "" >&2
    echo "  -o DIR   Write thread.md and downloaded images into DIR." >&2
    echo "           Without -o, outputs Markdown to stdout (images skipped)." >&2
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

URL="$1"
shift

OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o)
            [[ $# -lt 2 ]] && { echo "Error: -o requires a directory argument" >&2; exit 1; }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -o*)
            OUTPUT_DIR="${1#-o}"
            shift
            ;;
        *)
            usage
            ;;
    esac
done

SCRIPT_DIR="$(dirname "$0")"

if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
    gh slackdump -u "$URL" | python3 "$SCRIPT_DIR/format_slackdump_as_md.py" -o "$OUTPUT_DIR"
else
    gh slackdump -u "$URL" | python3 "$SCRIPT_DIR/format_slackdump_as_md.py"
fi
