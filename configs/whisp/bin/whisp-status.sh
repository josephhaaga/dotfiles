#!/usr/bin/env bash
# whisp-status.sh <state> [message]
# Writes /tmp/whisp/status.json which the Übersicht OSD widget polls.
# States: chord | idle | recording | transcribing | rewriting | inserted | error
set -euo pipefail

WHISP_TAG=status
DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
# shellcheck source=/dev/null
source "$DIR/config.sh"
# shellcheck source=/dev/null
source "$WHISP_BIN_DIR/whisp-lib.sh"

state="${1:-idle}"
message="${2:-}"

# Special pseudo-state: on returning to skhd's default mode, only clear the
# overlay if we're still showing the which-key panel (user backed out). If a
# recording/transcribe/rewrite is in flight, leave its status untouched.
if [ "$state" = "default-enter" ]; then
  cur=""
  if [ -r "$WHISP_STATUS" ]; then
    cur="$("$WHISP_JQ_BIN" -r '.state // empty' "$WHISP_STATUS" 2>/dev/null || true)"
  fi
  case "$cur" in
    chord|"") whisp_status idle ;;
    *)        : ;;  # recording/transcribing/rewriting/inserted/error: keep it
  esac
  exit 0
fi

whisp_status "$state" "$message"
