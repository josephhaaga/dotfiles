#!/bin/bash

# Capture read-only diagnostics for macOS's UserNotificationCenter process.
# Usage: scripts/inspect-user-notification-center.sh [PID] [OUTPUT_DIRECTORY]

set -u

PROCESS_NAME="UserNotificationCenter"
APP_PATH="/System/Library/CoreServices/UserNotificationCenter.app"
SAMPLE_SECONDS=5

usage() {
  cat <<'EOF'
Usage: inspect-user-notification-center.sh [PID] [OUTPUT_DIRECTORY]

Captures diagnostics for the current UserNotificationCenter process. If PID is
omitted, the script finds it. Results are written to a timestamped directory.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

pid="${1:-}"
if [ -z "$pid" ]; then
  pid="$(pgrep -x "$PROCESS_NAME" | head -n 1 || true)"
fi

if [ -z "$pid" ]; then
  echo "Could not find $PROCESS_NAME. Open Notification Center, then try again." >&2
  exit 1
fi

if ! kill -0 "$pid" 2>/dev/null; then
  echo "PID $pid is not running." >&2
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
output_root="${2:-${TMPDIR:-/tmp}}"
output_dir="$output_root/${PROCESS_NAME}-${pid}-${timestamp}"
mkdir -p "$output_dir"

capture() {
  local name="$1"
  shift
  "$@" >"$output_dir/$name" 2>&1 || true
}

echo "Capturing $PROCESS_NAME (PID $pid) to: $output_dir"

capture process.txt ps -p "$pid" -o pid,ppid,user,uid,etime,state,command
capture open-resources.txt lsof -nP -p "$pid"
capture memory-summary.txt vmmap -summary "$pid"
capture app-info.plist.txt plutil -p "$APP_PATH/Contents/Info.plist"
capture code-signing.txt codesign -dvvv "$APP_PATH"
capture launchd-services.txt launchctl list

if command -v yabai >/dev/null && command -v jq >/dev/null; then
  yabai -m query --windows \
    | jq --argjson pid "$pid" '.[] | select(.pid == $pid)' \
    >"$output_dir/windows.json" 2>"$output_dir/windows.error.txt" || true
else
  echo "Skipped: yabai and jq are both required for window inspection." \
    >"$output_dir/windows.json"
fi

capture recent-logs.txt log show --last 5m --style compact \
  --predicate "process == \"$PROCESS_NAME\""
capture stack-sample.txt sample "$pid" "$SAMPLE_SECONDS"

cat >"$output_dir/README.txt" <<EOF
UserNotificationCenter diagnostic capture

PID: $pid
Captured: $(date -Iseconds)

Files:
- process.txt: process identity and parent
- open-resources.txt: open files, sockets, and IPC resources
- memory-summary.txt: virtual-memory map summary
- app-info.plist.txt and code-signing.txt: Apple app metadata
- launchd-services.txt: all current launchd services (search for Notification)
- windows.json: yabai's current WindowServer view of this process
- recent-logs.txt: last five minutes of Unified Log entries for this process
- stack-sample.txt: five-second thread stack sample

Some fields may be redacted by macOS system protections. The script is read-only.
EOF

echo "Done. Start with: $output_dir/README.txt"
